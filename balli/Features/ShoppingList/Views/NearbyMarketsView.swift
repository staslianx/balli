//
//  NearbyMarketsView.swift
//  balli
//
//  In-app Maps modal showing nearby markets with directions
//

import SwiftUI
@preconcurrency import MapKit
import CoreLocation
import OSLog

struct NearbyMarketsView: View {
    private let logger = AppLoggers.Shopping.location

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMarket: MKMapItem?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597), // Ankara, Turkey default
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    var body: some View {
        NavigationStack {
            // Simple Map View - just like Apple Maps
            Map(position: $cameraPosition, selection: $selectedMarket) {
                // User location - show current location
                UserAnnotation()

                // Market markers - tap to get directions
                ForEach(searchResults, id: \.self) { market in
                    markerContent(for: market)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onAppear {
                Task {
                    await requestLocationAndSearch()
                }
            }
            .onChange(of: selectedMarket) { _, newSelection in
                if let market = newSelection {
                    // Open directions when marker is tapped
                    market.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                }
            }
            .onChange(of: locationManager.location) { _, newLocation in
                if let location = newLocation {
                    // Update camera to user location when we get it
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                    
                    // Search for markets around new location
                    Task {
                        await searchNearbyMarkets()
                    }
                }
            }
            .navigationTitle("Yakındaki Marketler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
    }

    @MapContentBuilder
    private func markerContent(for market: MKMapItem) -> some MapContent {
        let location = market.location
        Marker(
            market.name ?? "Marketler",
            coordinate: location.coordinate
        )
        .tint(.red)
        .tag(market)
    }

    private func requestLocationAndSearch() async {
        await MainActor.run {
            locationManager.requestLocation()
        }
        
        // Wait for location then search
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await searchNearbyMarkets()
    }
    
    private func searchNearbyMarkets() async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "Market Supermarket Grocery Store"

        // Use either current location or default Ankara location
        let searchLocation = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)

        searchRequest.region = MKCoordinateRegion(
            center: searchLocation,
            latitudinalMeters: 5000, // 5km radius
            longitudinalMeters: 5000
        )

        let search = MKLocalSearch(request: searchRequest)
        let logger = self.logger

        do {
            let response = try await search.start()
            await MainActor.run {
                searchResults = response.mapItems
                logger.info("Found \(response.mapItems.count) nearby markets")
            }
        } catch {
            logger.error("Market search failed: \(error.localizedDescription)")
            // Try simple search as fallback
            await searchWithSimpleQuery()
        }
    }
    
    private func searchWithSimpleQuery() async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "Market"

        let searchLocation = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
        searchRequest.region = MKCoordinateRegion(
            center: searchLocation,
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )

        let search = MKLocalSearch(request: searchRequest)
        let logger = self.logger

        do {
            let response = try await search.start()
            await MainActor.run {
                searchResults = response.mapItems
                logger.info("Found \(response.mapItems.count) markets with fallback search")
            }
        } catch {
            logger.error("Fallback market search also failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Simple Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let logger = AppLoggers.Shopping.location
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        Task {
            await MainActor.run {
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyBest
            }
        }
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            location = locations.first
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let logger = self.logger
        logger.error("Location error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }
}

#Preview {
    NearbyMarketsView()
}