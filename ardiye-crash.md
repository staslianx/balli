== DATE:

    5 November 2025 Wednesday at 11:30:12 GMT+03:00
    
    2025-11-05T08:30:12Z



== PAUSED REASON:

    processCrashed



== PREVIEW UPDATE ERROR:

    CrashReportError: balli crashed
    
    balli crashed. Check ~/Library/Logs/DiagnosticReports for crash logs from your application.
    
    Process:             balli [1806]
    Path:                <none>
    
    Date/Time:           2025-11-05 08:30:07 +0000
    
    Application Specific Information:
        dyld:
            dyld config: DYLD_SHARED_CACHE_DIR=/Library/Developer/CoreSimulator/Caches/dyld/25B77/com.apple.CoreSimulator.SimRuntime.iOS-26-1.23B80/ DYLD_ROOT_PATH=/Library/Developer/CoreSimulator/Volumes/iOS_23B80/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.1.simruntime/Contents/Resources/RuntimeRoot DYLD_LIBRARY_PATH=/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator DYLD_INSERT_LIBRARIES=@executable_path/__preview.dylib:/Library/Developer/CoreSimulator/Volumes/iOS_23B80/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.1.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libLogRedirect.dylib:/System/Library/PrivateFrameworks/LiveExecutionResultsProbe.framework/LiveExecutionResultsProbe:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator/libLiveExecutionResultsLogger.dylib:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator/libPlaygrounds.dylib:/System/Library/PrivateFrameworks/PreviewsInjection.framework/PreviewsInjection DYLD_FRAMEWORK_PATH=/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator DYLD_FALLBACK_FRAMEWORK_PATH=/Library/Developer/CoreSimulator/Volumes/iOS_23B80/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.1.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks DYLD_FALLBACK_LIBRARY_PATH=/Library/Developer/CoreSimulator/Volumes/iOS_23B80/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.1.simruntime/Contents/Resources/RuntimeRoot/usr/lib
        libsystem_sim_platform.dylib:
            CoreSimulator 1051.9.4 - Device: iPhone 17 Pro (D0E92A2A-0E03-4D79-BCF1-F17C5C91ECC9) - Runtime: iOS 26.1 (23B80) - DeviceType: iPhone 17 Pro
        libsystem_c.dylib:
            abort() called
    
    Termination Reason:  Namespace SIGNAL, Code 6, Abort trap: 6
    Terminating Process: balli [1806]
    
    Crashing Thread:
    0    libsystem_kernel.dylib              0x00000885c __pthread_kill + 8
    1    libsystem_pthread.dylib             0x0000062a8 pthread_kill + 264
    2    libsystem_c.dylib                   0x000074a0c __abort + 108
    3    libsystem_c.dylib                   0x0000749a0 abort + 112
    4    ???                                 0x345003bc8 __ZL22FIRCLSTerminateHandlerv
    5    libc++abi.dylib                     0x000010758 std::__terminate(void (*)()) + 12
    6    libc++abi.dylib                     0x0000139b0 __cxa_rethrow + 128
    7    ???                                 0x345006858 __ZL35FIRCLSCatchAndRecordActiveExceptionPSt9type_info
    8    ???                                 0x345003bfc __ZL22FIRCLSTerminateHandlerv
    9    libc++abi.dylib                     0x000010758 std::__terminate(void (*)()) + 12
    10   libc++abi.dylib                     0x0000139b0 __cxa_rethrow + 128
    11   libobjc.A.dylib                     0x00002c228 objc_exception_rethrow + 40
    12   CoreData                            0x0000da3bc developerSubmittedBlockToNSManagedObjectContextPerform + 628
    13   CoreData                            0x0000da0c0 -[NSManagedObjectContext performBlockAndWait:] + 256
    14   CoreData                            0x00013f434 -[NSFetchedResultsController _recursivePerformBlockAndWait:withContext:] + 124
    15   CoreData                            0x00013c46c -[NSFetchedResultsController performFetch:] + 208
    16   SwiftUI                             0x0002adf58 FetchController.update(in:) + 1052
    17   SwiftUI                             0x000c852e8 FetchRequest.update(_:) + 508
    18   SwiftUI                             0x000c85544 FetchRequest.update() + 376
    19   SwiftUICore                         0x000509b74 EmbeddedDynamicPropertyBox.update(property:phase:) + 32
    20   SwiftUICore                         0x0004729c8 static BoxVTable.update(elt:property:phase:) + 248
    21   SwiftUICore                         0x000471a98 _DynamicPropertyBuffer.update(container:phase:) + 128
    22   SwiftUICore                         0x00050b8ec closure #1 in closure #1 in DynamicBody.updateValue() + 204
    23   SwiftUICore                         0x00050d368 partial apply for closure #1 in closure #1 in DynamicBody.updateValue() + 28
    24   SwiftUICore                         0x000270b7c <deduplicated_symbol> + 72
    25   SwiftUICore                         0x00050b4d4 closure #1 in DynamicBody.updateValue() + 296
    26   SwiftUICore                         0x00050b0f0 DynamicBody.updateValue() + 836
    27   SwiftUICore                         0x00027db54 partial apply for implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 28
    28   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    29   AttributeGraph                      0x00000be18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
    30   AttributeGraph                      0x000013534 AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
    31   AttributeGraph                      0x00002b19c AGGraphGetValue + 236
    32   SwiftUICore                         0x00050a57c StaticBody.container.getter + 80
    33   SwiftUICore                         0x00050ab90 closure #1 in StaticBody.updateValue() + 232
    34   SwiftUICore                         0x00050a808 StaticBody.updateValue() + 572
    35   SwiftUICore                         0x00027db54 partial apply for implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 28
    36   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    37   AttributeGraph                      0x00000be18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
    38   AttributeGraph                      0x000013534 AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
    39   AttributeGraph                      0x00002b19c AGGraphGetValue + 236
    40   SwiftUICore                         0x0008fbc6c DynamicViewList.updateValue() + 280
    41   SwiftUICore                         0x00027db54 partial apply for implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 28
    42   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    43   AttributeGraph                      0x00000be18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
    44   AttributeGraph                      0x000013534 AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
    45   AttributeGraph                      0x00002b19c AGGraphGetValue + 236
    46   SwiftUICore                         0x0005c031c LayoutChildGeometries.value.getter + 48
    47   SwiftUICore                         0x000652b54 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 56
    48   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    49   AttributeGraph                      0x00000be18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
    50   AttributeGraph                      0x000013534 AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
    51   AttributeGraph                      0x00002b19c AGGraphGetValue + 236
    52   SwiftUICore                         0x0005c9820 DynamicLayoutViewChildGeometry.updateValue() + 244
    53   SwiftUICore                         0x00017ba40 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 20
    54   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    55   AttributeGraph                      0x00000be18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
    56   AttributeGraph                      0x000013534 AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
    57   AttributeGraph                      0x00002b19c AGGraphGetValue + 236
    58   SwiftUICore                         0x00081609c AnimatableFrameAttribute.updateValue() + 68
    59   SwiftUICore                         0x0001788f8 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 20
    60   AttributeGraph                      0x00000b728 AG::Graph::UpdateStack::update() + 492
    61   AttributeGraph                      0x00001a874 AG::Subgraph::update(unsigned int) + 944
    62   SwiftUICore                         0x00074ffe4 specialized GraphHost.runTransaction(_:do:id:) + 372
    63   SwiftUICore                         0x0007357a4 GraphHost.flushTransactions() + 180
    64   SwiftUI                             0x000240cb4 <deduplicated_symbol> + 20
    65   SwiftUICore                         0x0008f7348 <deduplicated_symbol> + 20
    66   SwiftUICore                         0x000b29aa8 ViewGraphRootValueUpdater._updateViewGraph<A>(body:) + 200
    67   SwiftUICore                         0x000b28154 ViewGraphRootValueUpdater.updateGraph<A>(body:) + 136
    68   SwiftUI                             0x000240c84 closure #1 in closure #1 in closure #1 in _UIHostingView.beginTransaction() + 144
    69   SwiftUI                             0x00024a444 partial apply for closure #1 in closure #1 in closure #1 in _UIHostingView.beginTransaction() + 20
    70   SwiftUICore                         0x00050f414 closure #1 in static Update.ensure<A>(_:) + 48
    71   SwiftUICore                         0x00050dd14 static Update.ensure<A>(_:) + 96
    72   SwiftUI                             0x00024a420 partial apply for closure #1 in closure #1 in _UIHostingView.beginTransaction() + 64
    73   UIKitCore                           0x00009a578 ???
    74   UIKitCore                           0x0001794b4 ???
    75   UIKitCore                           0x00001d98c ???
    76   SwiftUICore                         0x00050e520 static Update.dispatchImmediately<A>(reason:_:) + 300
    77   SwiftUICore                         0x00023f448 static ViewGraphHostUpdate.dispatchImmediately<A>(_:) + 40
    78   UIKitCore                           0x0001797e8 ???
    79   UIKitCore                           0x0001792a8 ???
    80   UIKitCore                           0x000689634 _UIUpdateSequenceRunNext + 120
    81   UIKitCore                           0x0010bbc24 schedulerStepScheduledMainSectionContinue + 56
    82   UpdateCycle                         0x0000012b4 UC::DriverCore::continueProcessing() + 80
    83   CoreFoundation                      0x0000574ac __CFMachPortPerform + 164
    84   CoreFoundation                      0x000093aa8 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__ + 56
    85   CoreFoundation                      0x0000930c0 __CFRunLoopDoSource1 + 480
    86   CoreFoundation                      0x000092188 __CFRunLoopRun + 2100
    87   CoreFoundation                      0x00008ccec _CFRunLoopRunSpecificWithOptions + 496
    88   GraphicsServices                    0x0000029bc GSEventRunModal + 116
    89   UIKitCore                           0x0011a00d8 -[UIApplication _run] + 772
    90   UIKitCore                           0x0011a4300 UIApplicationMain + 124
    91   SwiftUI                             0x0007b9128 closure #1 in KitRendererCommon(_:) + 164
    92   SwiftUI                             0x0007b8e70 runApp<A>(_:) + 180
    93   SwiftUI                             0x000546f34 static App.main() + 148
    94   ???                                 0x3400fd96c _$s5balli0A3AppV5$mainyyFZ
    95   ???                                 0x3400fd9ac _main
    96   balli                               0x0000014f0 __debug_blank_executor_run_user_entry_point + 148
    97   PreviewsInjection                   0x000025a78 ???
    98   PreviewsInjection                   0x0000263a8 ???
    99   PreviewsInjection                   0x0000262cc __previews_injection_run_user_entrypoint + 12
    100  XOJITExecutor                       0x000005df4 __xojit_executor_run_program_wrapper + 1460
    101  XOJITExecutor                       0x0000022c0 ???
    102  PreviewsInjection                   0x000026218 ???
    103  balli                               0x000000cc0 __debug_blank_executor_main + 992
    104  ???                                 0x104fd13d0 ???
    105  dyld                                0x000008d54 start + 7184
    
    Binary Images:
           0x105288000 dyld <b50f5a1a-be81-3068-92e1-3554f2be478a> /usr/lib/dyld
           0x104e7c000 balli <8e8f2b52-b030-3586-85cd-8c8a296770be> /Users/USER/Library/Developer/Xcode/UserData/Previews/Simulator Devices/D0E92A2A-0E03-4D79-BCF1-F17C5C91ECC9/data/Containers/Bundle/Application/FBF7829A-AA32-4C01-94F7-9891772B9FA1/balli.app/balli
           0x104ea0000 __preview.dylib <f1657004-fc17-348d-939f-3d370b173006> /Users/USER/Library/Developer/Xcode/UserData/Previews/Simulator Devices/D0E92A2A-0E03-4D79-BCF1-F17C5C91ECC9/data/Containers/Bundle/Application/FBF7829A-AA32-4C01-94F7-9891772B9FA1/balli.app/__preview.dylib
           0x104ed0000 libLogRedirect.dylib <6edd5d7a-6fea-32af-ac92-e91489d02287> /Volumes/VOLUME/*/libLogRedirect.dylib
           0x10508c000 libLiveExecutionResultsLogger.dylib <07517efe-1ffc-362f-800b-e8353e01b5a7> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator/libLiveExecutionResultsLogger.dylib
           0x104f64000 libPlaygrounds.dylib <8b670afd-4df4-3d7e-be02-f9bf54707230> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator/libPlaygrounds.dylib
           0x104eac000 libsystem_platform.dylib <af547fd5-445c-3167-911e-194532cf1f08> /usr/lib/system/libsystem_platform.dylib
           0x104ee4000 libsystem_kernel.dylib <545f62d1-ac22-3ce8-a7d6-53b08a143e8e> /usr/lib/system/libsystem_kernel.dylib
           0x105160000 libsystem_pthread.dylib <24a6e967-2095-367a-a315-dcdf05eef42e> /usr/lib/system/libsystem_pthread.dylib
           0x105584000 libobjc-trampolines.dylib <f766081e-2450-3187-beb3-a18b5d825986> /Volumes/VOLUME/*/libobjc-trampolines.dylib
           0x180141000 libsystem_c.dylib <4be317ce-e19b-36b1-809a-b1fbf17587a8> /Volumes/VOLUME/*/libsystem_c.dylib
           0x000000000 ??? <00000000-0000-0000-0000-000000000000> ???
           0x1802f2000 libc++abi.dylib <854f9986-f066-3a26-8bd7-4c14dd25f58e> /Volumes/VOLUME/*/libc++abi.dylib
           0x180070000 libobjc.A.dylib <bb867be3-83c2-3d97-84ef-4661b648229c> /Volumes/VOLUME/*/libobjc.A.dylib
           0x187699000 CoreData <d9c235ad-6352-3e0a-9a65-c0f8cb7bb352> /Volumes/VOLUME/*/CoreData.framework/CoreData
           0x1d96c4000 SwiftUI <3fb8c314-d240-31b9-9bc6-98125def417c> /Volumes/VOLUME/*/SwiftUI.framework/SwiftUI
           0x1da849000 SwiftUICore <3f7614dd-d0f7-3ca9-8751-ee3a4e2f51b0> /Volumes/VOLUME/*/SwiftUICore.framework/SwiftUICore
           0x1c4174000 AttributeGraph <f3c7b4a6-9ccb-36f2-a13b-79700d884727> /Volumes/VOLUME/*/AttributeGraph.framework/AttributeGraph
           0x18516f000 UIKitCore <48cabc6f-b0cb-351b-8893-7494813ec3a9> /Volumes/VOLUME/*/UIKitCore.framework/UIKitCore
           0x24ffc5000 UpdateCycle <2f470b4d-48c2-369f-9905-7e01b9606cc4> /Volumes/VOLUME/*/UpdateCycle.framework/UpdateCycle
           0x1803c3000 CoreFoundation <1ce7a90d-1134-3bfe-b564-88755edd6c85> /Volumes/VOLUME/*/CoreFoundation.framework/CoreFoundation
           0x1926bc000 GraphicsServices <4150c740-636d-3fba-a5f1-3e1483221156> /Volumes/VOLUME/*/GraphicsServices.framework/GraphicsServices
           0x241122000 PreviewsInjection <b9c5e9f6-18e5-3a9a-a3da-076c74998b89> /Volumes/VOLUME/*/PreviewsInjection.framework/PreviewsInjection
           0x25441c000 XOJITExecutor <d50e4199-32b9-3f2e-86c0-ebd88d1a55ce> /Volumes/VOLUME/*/XOJITExecutor.framework/XOJITExecutor
           0x1801bf000 libdispatch.dylib <da1dd2f7-9f16-387c-9c54-fe18cccb12d9> /Volumes/VOLUME/*/libdispatch.dylib
           0x18085f000 Foundation <249188a3-8f44-3d76-acb0-0345a43eb0a3> /Volumes/VOLUME/*/Foundation.framework/Foundation
           0x184c9d000 CFNetwork <e8f01728-c4af-3b4f-b340-af39876bf31d> /Volumes/VOLUME/*/CFNetwork.framework/CFNetwork
    
    EOF



== VERSION INFO:

    Tools: 17B54
    OS:    25B77
    PID:   32073
    Model: Mac mini
    Arch:  arm64e



== EXECUTION MODE PROPERTIES:

    Automatically Refresh Previews: true
    JIT Mode User Enabled: true
    Falling back to Dynamic Replacement: false



== PACKAGE RESOLUTION ERRORS:

    



== REFERENCED SOURCE PACKAGES:

    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c3c00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/abseil-cpp-binary'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c0000 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/GoogleDataTransport'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c0f00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/promises'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c2100 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/google-ads-on-device-conversion-ios-sdk'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c2a00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/interop-ios-for-google-sdks'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c1200 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/firebase-ios-sdk'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e37b6d00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/GoogleAppMeasurement'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c2d00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/grpc-binary'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c3600 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/gtm-session-fetcher'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c0900 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/GoogleUtilities'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c0300 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/nanopb'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c3000 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/swift-protobuf'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c0c00 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/app-check'>
    <IDESwiftPackageCore.IDESwiftPackageDependency:0x7e38c1500 path:'/Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/SourcePackages/checkouts/leveldb'>



== JIT LINKAGE:

    Run Destination: D937002D-43B2-4891-BABA-BA7C9B0E77E2-iphonesimulator26.1-arm64-iphonesimulator
    JIT Link Description {
        51:balli.app [
            4:FBLPromises
            3:FBLPromises
            22:Firebase
            38:FirebaseAppCheckInterop
            45:FirebaseAuthInterop
            23:FirebaseCore
            17:FirebaseCoreExtension
            21:FirebaseCoreInternal
            28:FirebaseCrashlytics
            27:FirebaseCrashlytics
            11:FirebaseCrashlyticsSwift
            42:FirebaseFirestore
            40:FirebaseFirestore
            39:FirebaseFirestoreInternalWrapper
            41:FirebaseFirestoreTarget
            25:FirebaseInstallations
            10:FirebaseRemoteConfigInterop
            26:FirebaseSessions
            24:FirebaseSessionsObjC
            37:FirebaseSharedSwift
            47:FirebaseStorage
            46:FirebaseStorage
            44:GTMSessionFetcherCore
            43:GTMSessionFetcherCore
            7:GULEnvironment
            18:GULLogger
            20:GULNSData
            14:GULUserDefaults
            9:GoogleDataTransport
            8:GoogleDataTransport
            6:GoogleUtilities-Environment
            12:GoogleUtilities-Logger
            19:GoogleUtilities-NSData
            13:GoogleUtilities-UserDefaults
            16:Promises
            15:Promises
            32:abseil
            31:abslWrapper
            36:gRPC-C++
            34:grpcWrapper
            35:grpcppWrapper
            30:leveldb
            29:leveldb
            2:nanopb
            1:nanopb
            33:opensslWrapper
            5:third-party-IsAppEncrypted
        ]
    }
    



== ENVIRONMENT:

    openFiles = [
        /Users/serhat/SW/balli/balli/App/ContentView.swift
    ]
    wantsNewBuildSystem = true
    newBuildSystemAvailable = true
    activeScheme = balli
    activeRunDestination = Serhat variant iphoneos arm64
    workspaceArena = [x]
    buildArena = [x]
    buildableEntries = [
        balli.app
    ]
    runMode = JIT Executor



== SELECTED RUN DESTINATION:

    iOS 26.1 | iphoneos | arm64 | iPhone 17 | no proxy



== SESSION GROUP 240 (START):

    workspace identifier: workspace:91AF1430-A73C-4929-806F-822199182741
    previewPreflights [
           Preview Preflight | Registry-ContentView.swift#1[preview]: from Editor(2604) for local
    ]
    externalRegistryPreflights [
    ]
    providers [
           Preview Provider | Registry-ContentView.swift#1[preview] [Editor(2604)]
    ]
    translation units [
           /Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift
           /Users/serhat/SW/balli/balli/App/ContentView.swift
    ]
    attributes: [
        Editor(2604):     
            isAppPreviewEnabled: false
            destinationMode: automatic
            previewSettings: [
                preview(Registry-RecipeMetadataSection.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(ArdiyeView_Previews provider #1 in ArdiyeView.swift[0]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-InformationRetrievalView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-ContentView.swift#1[preview]):     isEnabled: true
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
            ]
    ]
    update plan {
        iOS [arm64 iphonesimulator26.1 iphonesimulator] (iPhone 17 Pro, D937002D-43B2-4891-BABA-BA7C9B0E77E2-iphonesimulator26.1-arm64-iphonesimulator), [], thinning disabled, thunking enabled) {
            Destination: iPhone 17 Pro D937002D-43B2-4891-BABA-BA7C9B0E77E2 | default device for iphonesimulator [
                balli app - Previews {
                    execution point packs [
                        [source: ContentView.swift, role: Previews, domain: application] (in balli)
                        [source: ContentView.swift, role: Previews] (in balli)
                    ]
                    translation units [
                        ContentView.swift (in balli.app)
                        SearchBarView.swift (in balli.app)
                    ]
                    modules [
                        FBLPromises
                        FBLPromises
                        Firebase
                        FirebaseAppCheckInterop
                        FirebaseAuthInterop
                        FirebaseCore
                        FirebaseCoreExtension
                        FirebaseCoreInternal
                        FirebaseCrashlytics
                        FirebaseCrashlytics
                        FirebaseCrashlyticsSwift
                        FirebaseFirestore
                        FirebaseFirestore
                        FirebaseFirestoreInternalWrapper
                        FirebaseFirestoreTarget
                        FirebaseInstallations
                        FirebaseRemoteConfigInterop
                        FirebaseSessions
                        FirebaseSessionsObjC
                        FirebaseSharedSwift
                        FirebaseStorage
                        FirebaseStorage
                        GTMSessionFetcherCore
                        GTMSessionFetcherCore
                        GULEnvironment
                        GULLogger
                        GULNSData
                        GULUserDefaults
                        GoogleDataTransport
                        GoogleDataTransport
                        GoogleUtilities-Environment
                        GoogleUtilities-Logger
                        GoogleUtilities-NSData
                        GoogleUtilities-UserDefaults
                        Promises
                        Promises
                        abseil
                        abslWrapper
                        balli.app
                        gRPC-C++
                        grpcWrapper
                        grpcppWrapper
                        leveldb
                        leveldb
                        nanopb
                        nanopb
                        opensslWrapper
                        third-party-IsAppEncrypted
                    ]
                    jit link description [
                        balli.app {
                            merged static libs [
                                FBLPromises
                                FBLPromises
                                Firebase
                                FirebaseAppCheckInterop
                                FirebaseAuthInterop
                                FirebaseCore
                                FirebaseCoreExtension
                                FirebaseCoreInternal
                                FirebaseCrashlytics
                                FirebaseCrashlytics
                                FirebaseCrashlyticsSwift
                                FirebaseFirestore
                                FirebaseFirestore
                                FirebaseFirestoreInternalWrapper
                                FirebaseFirestoreTarget
                                FirebaseInstallations
                                FirebaseRemoteConfigInterop
                                FirebaseSessions
                                FirebaseSessionsObjC
                                FirebaseSharedSwift
                                FirebaseStorage
                                FirebaseStorage
                                GTMSessionFetcherCore
                                GTMSessionFetcherCore
                                GULEnvironment
                                GULLogger
                                GULNSData
                                GULUserDefaults
                                GoogleDataTransport
                                GoogleDataTransport
                                GoogleUtilities-Environment
                                GoogleUtilities-Logger
                                GoogleUtilities-NSData
                                GoogleUtilities-UserDefaults
                                Promises
                                Promises
                                abseil
                                abslWrapper
                                gRPC-C++
                                grpcWrapper
                                grpcppWrapper
                                leveldb
                                leveldb
                                nanopb
                                nanopb
                                opensslWrapper
                                third-party-IsAppEncrypted
                            ]
                        }
                    ]
                }
            ]
        }
    }
    Agent {
        identifier: Agent #68878 [Description #7058: com.anaxoniclabs.balli in workspace:91AF1430-A73C-4929-806F-822199182741]
        pid: 1806
    }
    Agent Launch Environment {
        Launch Arguments [
        ]
        Environment Variables {
            CFLOG_FORCE_DISABLE_STDERR: 1
            DYLD_FRAMEWORK_PATH: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
            DYLD_INSERT_LIBRARIES: /Library/Developer/CoreSimulator/Volumes/iOS_23B80/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.1.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libLogRedirect.dylib
            DYLD_LIBRARY_PATH: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
            IDE_DISABLED_OS_ACTIVITY_DT_MODE: 1
            LOGGER_DEPTH: 6
            OS_ACTIVITY_TOOLS_OVERSIZE: YES
            OS_ACTIVITY_TOOLS_PRIVACY: YES
            OS_LOG_DT_HOOK_MODE: 0x07
            OS_LOG_DT_HOOK_PREFIX: OSLOG-455C94C2-8BC5-48BC-B6E0-6AF21461A78B
            OS_LOG_TRANSLATE_PRINT_MODE: 0x80
            PACKAGE_RESOURCE_BUNDLE_PATH: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
            PLAYGROUND_LOGGER_FILTER: {"excludeImageResults":false,"generateQuickLook":true,"excludeViewResults":false,"generateSummaries":true,"encodeLogPackets":true,"captureSourceLineEvents":false,"renderSwiftUIViews":false,"createLogPackets":true,"captureScopeEvents":false}
            SQLITE_ENABLE_THREAD_ASSERTIONS: 1
            TERM: dumb
            XCODE_RUNNING_FOR_PLAYGROUNDS: 1
            __XCODE_BUILT_PRODUCTS_DIR_PATHS: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
            __XPC_DYLD_FRAMEWORK_PATH: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
            __XPC_DYLD_LIBRARY_PATH: /Users/serhat/Library/Developer/Xcode/DerivedData/balli-eqbxwgcxztsrrjfzmpxfchfgotnp/Build/Products/Debug-iphonesimulator
        }
    }



== SESSION GROUP 239 (START):

    workspace identifier: workspace:91AF1430-A73C-4929-806F-822199182741
    previewPreflights [
           Preview Preflight | Registry-ContentView.swift#1[preview]: from Editor(2604) for local
    ]
    externalRegistryPreflights [
    ]
    providers [
           Preview Provider | Registry-ContentView.swift#1[preview] [Editor(2604)]
    ]
    translation units [
           /Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift
           /Users/serhat/SW/balli/balli/App/ContentView.swift
    ]
    attributes: [
        Editor(2604):     
            isAppPreviewEnabled: false
            destinationMode: automatic
            previewSettings: [
                preview(Registry-RecipeMetadataSection.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#1[preview]):     isEnabled: true
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(ArdiyeView_Previews provider #1 in ArdiyeView.swift[0]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-InformationRetrievalView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-ContentView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
            ]
    ]
    build graph {
        balli.app (#51)
           FirebaseCrashlytics (#28)
              FirebaseCrashlytics (#27)
                 nanopb (#2)
                    nanopb (#1)
                 FBLPromises (#4)
                    FBLPromises (#3)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 GoogleDataTransport (#9)
                    GoogleDataTransport (#8)
                       nanopb (#2)
                          nanopb (#1)
                       FBLPromises (#4)
                          FBLPromises (#3)
                 FirebaseRemoteConfigInterop (#10)
                 FirebaseCrashlyticsSwift (#11)
                    FirebaseRemoteConfigInterop (#10)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseInstallations (#25)
                    FBLPromises (#4)
                       FBLPromises (#3)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                 FirebaseSessions (#26)
                    nanopb (#2)
                       nanopb (#1)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GoogleDataTransport (#9)
                       GoogleDataTransport (#8)
                          nanopb (#2)
                             nanopb (#1)
                          FBLPromises (#4)
                             FBLPromises (#3)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    Promises (#16)
                       Promises (#15)
                          FBLPromises (#3)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    FirebaseSessionsObjC (#24)
                       nanopb (#2)
                          nanopb (#1)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       FirebaseCoreExtension (#17)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
                    FirebaseInstallations (#25)
                       FBLPromises (#4)
                          FBLPromises (#3)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULUserDefaults (#14)
                          GoogleUtilities-UserDefaults (#13)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
           FirebaseFirestore (#42)
              FirebaseFirestoreTarget (#41)
                 FirebaseFirestore (#40)
                    nanopb (#2)
                       nanopb (#1)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    leveldb (#30)
                       leveldb (#29)
                    abseil (#32)
                       abslWrapper (#31)
                    gRPC-C++ (#36)
                       grpcppWrapper (#35)
                          abseil (#32)
                             abslWrapper (#31)
                          opensslWrapper (#33)
                          grpcWrapper (#34)
                    FirebaseSharedSwift (#37)
                    FirebaseAppCheckInterop (#38)
                    FirebaseFirestoreInternalWrapper (#39)
           FirebaseStorage (#47)
              FirebaseStorage (#46)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 FirebaseCoreExtension (#17)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseAppCheckInterop (#38)
                 GTMSessionFetcherCore (#44)
                    GTMSessionFetcherCore (#43)
                 FirebaseAuthInterop (#45)
           SearchBarView.swift (#48)
           sourceFile(file:///Users/serhat/SW/balli/balli/App/ContentView.swift -> ContentView.swift) (#49)
           ContentView.swift (#50)
    }
    update plan {
        iOS [arm64 iphonesimulator26.1 iphonesimulator] (iPhone 17 Pro, D937002D-43B2-4891-BABA-BA7C9B0E77E2-iphonesimulator26.1-arm64-iphonesimulator), [], thinning disabled, thunking enabled) {
            Destination: iPhone 17 Pro D937002D-43B2-4891-BABA-BA7C9B0E77E2 | default device for iphonesimulator [
                balli app - Previews {
                    execution point packs [
                        [source: ContentView.swift, role: Previews] (in balli)
                    ]
                    translation units [
                        ContentView.swift (in balli.app)
                        SearchBarView.swift (in balli.app)
                    ]
                    modules [
                        FBLPromises
                        FBLPromises
                        Firebase
                        FirebaseAppCheckInterop
                        FirebaseAuthInterop
                        FirebaseCore
                        FirebaseCoreExtension
                        FirebaseCoreInternal
                        FirebaseCrashlytics
                        FirebaseCrashlytics
                        FirebaseCrashlyticsSwift
                        FirebaseFirestore
                        FirebaseFirestore
                        FirebaseFirestoreInternalWrapper
                        FirebaseFirestoreTarget
                        FirebaseInstallations
                        FirebaseRemoteConfigInterop
                        FirebaseSessions
                        FirebaseSessionsObjC
                        FirebaseSharedSwift
                        FirebaseStorage
                        FirebaseStorage
                        GTMSessionFetcherCore
                        GTMSessionFetcherCore
                        GULEnvironment
                        GULLogger
                        GULNSData
                        GULUserDefaults
                        GoogleDataTransport
                        GoogleDataTransport
                        GoogleUtilities-Environment
                        GoogleUtilities-Logger
                        GoogleUtilities-NSData
                        GoogleUtilities-UserDefaults
                        Promises
                        Promises
                        abseil
                        abslWrapper
                        balli.app
                        gRPC-C++
                        grpcWrapper
                        grpcppWrapper
                        leveldb
                        leveldb
                        nanopb
                        nanopb
                        opensslWrapper
                        third-party-IsAppEncrypted
                    ]
                    jit link description [
                        balli.app {
                            merged static libs [
                                FBLPromises
                                FBLPromises
                                Firebase
                                FirebaseAppCheckInterop
                                FirebaseAuthInterop
                                FirebaseCore
                                FirebaseCoreExtension
                                FirebaseCoreInternal
                                FirebaseCrashlytics
                                FirebaseCrashlytics
                                FirebaseCrashlyticsSwift
                                FirebaseFirestore
                                FirebaseFirestore
                                FirebaseFirestoreInternalWrapper
                                FirebaseFirestoreTarget
                                FirebaseInstallations
                                FirebaseRemoteConfigInterop
                                FirebaseSessions
                                FirebaseSessionsObjC
                                FirebaseSharedSwift
                                FirebaseStorage
                                FirebaseStorage
                                GTMSessionFetcherCore
                                GTMSessionFetcherCore
                                GULEnvironment
                                GULLogger
                                GULNSData
                                GULUserDefaults
                                GoogleDataTransport
                                GoogleDataTransport
                                GoogleUtilities-Environment
                                GoogleUtilities-Logger
                                GoogleUtilities-NSData
                                GoogleUtilities-UserDefaults
                                Promises
                                Promises
                                abseil
                                abslWrapper
                                gRPC-C++
                                grpcWrapper
                                grpcppWrapper
                                leveldb
                                leveldb
                                nanopb
                                nanopb
                                opensslWrapper
                                third-party-IsAppEncrypted
                            ]
                        }
                    ]
                }
            ]
        }
    }



== SESSION GROUP 238 (START):

    workspace identifier: workspace:91AF1430-A73C-4929-806F-822199182741
    previewPreflights [
           Preview Preflight | Registry-SearchBarView.swift#3[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#6[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#5[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#4[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#2[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#1[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#7[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#8[preview]: from Editor(2604) for local
    ]
    externalRegistryPreflights [
    ]
    providers [
           Preview Provider | Registry-SearchBarView.swift#5[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#3[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#7[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#1[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#4[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#6[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#2[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#8[preview] [Editor(2604)]
    ]
    translation units [
           /Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift
    ]
    attributes: [
        Editor(2604):     
            isAppPreviewEnabled: false
            destinationMode: automatic
            previewSettings: [
                preview(Registry-RecipeMetadataSection.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#1[preview]):     isEnabled: true
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(ArdiyeView_Previews provider #1 in ArdiyeView.swift[0]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-InformationRetrievalView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-ContentView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
            ]
    ]
    build graph {
        balli.app (#50)
           FirebaseCrashlytics (#28)
              FirebaseCrashlytics (#27)
                 nanopb (#2)
                    nanopb (#1)
                 FBLPromises (#4)
                    FBLPromises (#3)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 GoogleDataTransport (#9)
                    GoogleDataTransport (#8)
                       nanopb (#2)
                          nanopb (#1)
                       FBLPromises (#4)
                          FBLPromises (#3)
                 FirebaseRemoteConfigInterop (#10)
                 FirebaseCrashlyticsSwift (#11)
                    FirebaseRemoteConfigInterop (#10)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseInstallations (#25)
                    FBLPromises (#4)
                       FBLPromises (#3)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                 FirebaseSessions (#26)
                    nanopb (#2)
                       nanopb (#1)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GoogleDataTransport (#9)
                       GoogleDataTransport (#8)
                          nanopb (#2)
                             nanopb (#1)
                          FBLPromises (#4)
                             FBLPromises (#3)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    Promises (#16)
                       Promises (#15)
                          FBLPromises (#3)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    FirebaseSessionsObjC (#24)
                       nanopb (#2)
                          nanopb (#1)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       FirebaseCoreExtension (#17)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
                    FirebaseInstallations (#25)
                       FBLPromises (#4)
                          FBLPromises (#3)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULUserDefaults (#14)
                          GoogleUtilities-UserDefaults (#13)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
           FirebaseFirestore (#42)
              FirebaseFirestoreTarget (#41)
                 FirebaseFirestore (#40)
                    nanopb (#2)
                       nanopb (#1)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    leveldb (#30)
                       leveldb (#29)
                    abseil (#32)
                       abslWrapper (#31)
                    gRPC-C++ (#36)
                       grpcppWrapper (#35)
                          abseil (#32)
                             abslWrapper (#31)
                          opensslWrapper (#33)
                          grpcWrapper (#34)
                    FirebaseSharedSwift (#37)
                    FirebaseAppCheckInterop (#38)
                    FirebaseFirestoreInternalWrapper (#39)
           FirebaseStorage (#47)
              FirebaseStorage (#46)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 FirebaseCoreExtension (#17)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseAppCheckInterop (#38)
                 GTMSessionFetcherCore (#44)
                    GTMSessionFetcherCore (#43)
                 FirebaseAuthInterop (#45)
           sourceFile(file:///Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift -> SearchBarView.swift) (#48)
           SearchBarView.swift (#49)
    }
    update plan {
        iOS [arm64 iphonesimulator26.1 iphonesimulator] (iPhone 17 Pro, D937002D-43B2-4891-BABA-BA7C9B0E77E2-iphonesimulator26.1-arm64-iphonesimulator), [], thinning disabled, thunking enabled) {
            Destination: iPhone 17 Pro D937002D-43B2-4891-BABA-BA7C9B0E77E2 | default device for iphonesimulator [
                balli app - Previews {
                    execution point packs [
                        [source: SearchBarView.swift, role: Previews, domain: application] (in balli)
                        [source: SearchBarView.swift, role: Previews] (in balli)
                    ]
                    translation units [
                        SearchBarView.swift (in balli.app)
                    ]
                    modules [
                        FBLPromises
                        FBLPromises
                        Firebase
                        FirebaseAppCheckInterop
                        FirebaseAuthInterop
                        FirebaseCore
                        FirebaseCoreExtension
                        FirebaseCoreInternal
                        FirebaseCrashlytics
                        FirebaseCrashlytics
                        FirebaseCrashlyticsSwift
                        FirebaseFirestore
                        FirebaseFirestore
                        FirebaseFirestoreInternalWrapper
                        FirebaseFirestoreTarget
                        FirebaseInstallations
                        FirebaseRemoteConfigInterop
                        FirebaseSessions
                        FirebaseSessionsObjC
                        FirebaseSharedSwift
                        FirebaseStorage
                        FirebaseStorage
                        GTMSessionFetcherCore
                        GTMSessionFetcherCore
                        GULEnvironment
                        GULLogger
                        GULNSData
                        GULUserDefaults
                        GoogleDataTransport
                        GoogleDataTransport
                        GoogleUtilities-Environment
                        GoogleUtilities-Logger
                        GoogleUtilities-NSData
                        GoogleUtilities-UserDefaults
                        Promises
                        Promises
                        abseil
                        abslWrapper
                        balli.app
                        gRPC-C++
                        grpcWrapper
                        grpcppWrapper
                        leveldb
                        leveldb
                        nanopb
                        nanopb
                        opensslWrapper
                        third-party-IsAppEncrypted
                    ]
                    jit link description [
                        balli.app {
                            merged static libs [
                                FBLPromises
                                FBLPromises
                                Firebase
                                FirebaseAppCheckInterop
                                FirebaseAuthInterop
                                FirebaseCore
                                FirebaseCoreExtension
                                FirebaseCoreInternal
                                FirebaseCrashlytics
                                FirebaseCrashlytics
                                FirebaseCrashlyticsSwift
                                FirebaseFirestore
                                FirebaseFirestore
                                FirebaseFirestoreInternalWrapper
                                FirebaseFirestoreTarget
                                FirebaseInstallations
                                FirebaseRemoteConfigInterop
                                FirebaseSessions
                                FirebaseSessionsObjC
                                FirebaseSharedSwift
                                FirebaseStorage
                                FirebaseStorage
                                GTMSessionFetcherCore
                                GTMSessionFetcherCore
                                GULEnvironment
                                GULLogger
                                GULNSData
                                GULUserDefaults
                                GoogleDataTransport
                                GoogleDataTransport
                                GoogleUtilities-Environment
                                GoogleUtilities-Logger
                                GoogleUtilities-NSData
                                GoogleUtilities-UserDefaults
                                Promises
                                Promises
                                abseil
                                abslWrapper
                                gRPC-C++
                                grpcWrapper
                                grpcppWrapper
                                leveldb
                                leveldb
                                nanopb
                                nanopb
                                opensslWrapper
                                third-party-IsAppEncrypted
                            ]
                        }
                    ]
                }
            ]
        }
    }



== SESSION GROUP 237 (START):

    workspace identifier: workspace:91AF1430-A73C-4929-806F-822199182741
    previewPreflights [
           Preview Preflight | Registry-SearchBarView.swift#5[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#4[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#6[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#8[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#1[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#2[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#3[preview]: from Editor(2604) for local
           Preview Preflight | Registry-SearchBarView.swift#7[preview]: from Editor(2604) for local
    ]
    externalRegistryPreflights [
    ]
    providers [
           Preview Provider | Registry-SearchBarView.swift#5[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#4[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#2[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#6[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#1[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#8[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#3[preview] [Editor(2604)]
           Preview Provider | Registry-SearchBarView.swift#7[preview] [Editor(2604)]
    ]
    translation units [
           /Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift
    ]
    attributes: [
        Editor(2604):     
            isAppPreviewEnabled: false
            destinationMode: automatic
            previewSettings: [
                preview(Registry-RecipeMetadataSection.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#1[preview]):     isEnabled: true
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#2[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(ArdiyeView_Previews provider #1 in ArdiyeView.swift[0]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-InformationRetrievalView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-UserSelectionView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#3[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-SearchBarView.swift#4[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-ContentView.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
                preview(Registry-RecipeMetadataSection.swift#1[preview]):     isEnabled: false
                    boxedCanvasControlStates: []
            ]
    ]
    build graph {
        balli.app (#50)
           FirebaseCrashlytics (#28)
              FirebaseCrashlytics (#27)
                 nanopb (#2)
                    nanopb (#1)
                 FBLPromises (#4)
                    FBLPromises (#3)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 GoogleDataTransport (#9)
                    GoogleDataTransport (#8)
                       nanopb (#2)
                          nanopb (#1)
                       FBLPromises (#4)
                          FBLPromises (#3)
                 FirebaseRemoteConfigInterop (#10)
                 FirebaseCrashlyticsSwift (#11)
                    FirebaseRemoteConfigInterop (#10)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseInstallations (#25)
                    FBLPromises (#4)
                       FBLPromises (#3)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                 FirebaseSessions (#26)
                    nanopb (#2)
                       nanopb (#1)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GoogleDataTransport (#9)
                       GoogleDataTransport (#8)
                          nanopb (#2)
                             nanopb (#1)
                          FBLPromises (#4)
                             FBLPromises (#3)
                    GULUserDefaults (#14)
                       GoogleUtilities-UserDefaults (#13)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                    Promises (#16)
                       Promises (#15)
                          FBLPromises (#3)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    FirebaseSessionsObjC (#24)
                       nanopb (#2)
                          nanopb (#1)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       FirebaseCoreExtension (#17)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
                    FirebaseInstallations (#25)
                       FBLPromises (#4)
                          FBLPromises (#3)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULUserDefaults (#14)
                          GoogleUtilities-UserDefaults (#13)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                       FirebaseCore (#23)
                          GULEnvironment (#7)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                          GULLogger (#18)
                             GoogleUtilities-Logger (#12)
                                GoogleUtilities-Environment (#6)
                                   third-party-IsAppEncrypted (#5)
                          FirebaseCoreInternal (#21)
                             GULNSData (#20)
                                GoogleUtilities-NSData (#19)
                          Firebase (#22)
           FirebaseFirestore (#42)
              FirebaseFirestoreTarget (#41)
                 FirebaseFirestore (#40)
                    nanopb (#2)
                       nanopb (#1)
                    FirebaseCoreExtension (#17)
                    FirebaseCore (#23)
                       GULEnvironment (#7)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                       GULLogger (#18)
                          GoogleUtilities-Logger (#12)
                             GoogleUtilities-Environment (#6)
                                third-party-IsAppEncrypted (#5)
                       FirebaseCoreInternal (#21)
                          GULNSData (#20)
                             GoogleUtilities-NSData (#19)
                       Firebase (#22)
                    leveldb (#30)
                       leveldb (#29)
                    abseil (#32)
                       abslWrapper (#31)
                    gRPC-C++ (#36)
                       grpcppWrapper (#35)
                          abseil (#32)
                             abslWrapper (#31)
                          opensslWrapper (#33)
                          grpcWrapper (#34)
                    FirebaseSharedSwift (#37)
                    FirebaseAppCheckInterop (#38)
                    FirebaseFirestoreInternalWrapper (#39)
           FirebaseStorage (#47)
              FirebaseStorage (#46)
                 GULEnvironment (#7)
                    GoogleUtilities-Environment (#6)
                       third-party-IsAppEncrypted (#5)
                 FirebaseCoreExtension (#17)
                 FirebaseCore (#23)
                    GULEnvironment (#7)
                       GoogleUtilities-Environment (#6)
                          third-party-IsAppEncrypted (#5)
                    GULLogger (#18)
                       GoogleUtilities-Logger (#12)
                          GoogleUtilities-Environment (#6)
                             third-party-IsAppEncrypted (#5)
                    FirebaseCoreInternal (#21)
                       GULNSData (#20)
                          GoogleUtilities-NSData (#19)
                    Firebase (#22)
                 FirebaseAppCheckInterop (#38)
                 GTMSessionFetcherCore (#44)
                    GTMSessionFetcherCore (#43)
                 FirebaseAuthInterop (#45)
           sourceFile(file:///Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift -> SearchBarView.swift) (#48)
           SearchBarView.swift (#49)
    }
    update plan {
        iOS [arm64 iphonesimulator26.1 iphonesimulator] (iPhone 17 Pro, D937002D-43B2-4891-BABA-BA7C9B0E77E2-iphonesimulator26.1-arm64-iphonesimulator), [], thinning disabled, thunking enabled) {
            Destination: iPhone 17 Pro D937002D-43B2-4891-BABA-BA7C9B0E77E2 | default device for iphonesimulator [
                balli app - Previews {
                    execution point packs [
                        [source: SearchBarView.swift, role: Previews, domain: application] (in balli)
                        [source: SearchBarView.swift, role: Previews] (in balli)
                    ]
                    translation units [
                        SearchBarView.swift (in balli.app)
                    ]
                    modules [
                        FBLPromises
                        FBLPromises
                        Firebase
                        FirebaseAppCheckInterop
                        FirebaseAuthInterop
                        FirebaseCore
                        FirebaseCoreExtension
                        FirebaseCoreInternal
                        FirebaseCrashlytics
                        FirebaseCrashlytics
                        FirebaseCrashlyticsSwift
                        FirebaseFirestore
                        FirebaseFirestore
                        FirebaseFirestoreInternalWrapper
                        FirebaseFirestoreTarget
                        FirebaseInstallations
                        FirebaseRemoteConfigInterop
                        FirebaseSessions
                        FirebaseSessionsObjC
                        FirebaseSharedSwift
                        FirebaseStorage
                        FirebaseStorage
                        GTMSessionFetcherCore
                        GTMSessionFetcherCore
                        GULEnvironment
                        GULLogger
                        GULNSData
                        GULUserDefaults
                        GoogleDataTransport
                        GoogleDataTransport
                        GoogleUtilities-Environment
                        GoogleUtilities-Logger
                        GoogleUtilities-NSData
                        GoogleUtilities-UserDefaults
                        Promises
                        Promises
                        abseil
                        abslWrapper
                        balli.app
                        gRPC-C++
                        grpcWrapper
                        grpcppWrapper
                        leveldb
                        leveldb
                        nanopb
                        nanopb
                        opensslWrapper
                        third-party-IsAppEncrypted
                    ]
                    jit link description [
                        balli.app {
                            merged static libs [
                                FBLPromises
                                FBLPromises
                                Firebase
                                FirebaseAppCheckInterop
                                FirebaseAuthInterop
                                FirebaseCore
                                FirebaseCoreExtension
                                FirebaseCoreInternal
                                FirebaseCrashlytics
                                FirebaseCrashlytics
                                FirebaseCrashlyticsSwift
                                FirebaseFirestore
                                FirebaseFirestore
                                FirebaseFirestoreInternalWrapper
                                FirebaseFirestoreTarget
                                FirebaseInstallations
                                FirebaseRemoteConfigInterop
                                FirebaseSessions
                                FirebaseSessionsObjC
                                FirebaseSharedSwift
                                FirebaseStorage
                                FirebaseStorage
                                GTMSessionFetcherCore
                                GTMSessionFetcherCore
                                GULEnvironment
                                GULLogger
                                GULNSData
                                GULUserDefaults
                                GoogleDataTransport
                                GoogleDataTransport
                                GoogleUtilities-Environment
                                GoogleUtilities-Logger
                                GoogleUtilities-NSData
                                GoogleUtilities-UserDefaults
                                Promises
                                Promises
                                abseil
                                abslWrapper
                                gRPC-C++
                                grpcWrapper
                                grpcppWrapper
                                leveldb
                                leveldb
                                nanopb
                                nanopb
                                opensslWrapper
                                third-party-IsAppEncrypted
                            ]
                        }
                    ]
                }
            ]
        }
    }



== BUILD PRODUCTS CACHE:

    BuildCache {
        Incremental Values [
            file:///Users/serhat/SW/balli/balli/Features/FoodArchive/Views/ArdiyeView.swift -> ArdiyeView.swift {
                #20241_19: #20241_19 = 28
            }
            file:///Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/RecipeDetail/RecipeMetadataSection.swift -> RecipeMetadataSection.swift {
                #13306_2: #13306_2 = 6
                #13306_3: #13306_3 = -4
            }
            file:///Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift -> SearchBarView.swift {
                #53427_30: #53427_30 = 19
            }
            file:///Users/serhat/SW/balli/balli/Features/Research/Views/InformationRetrievalView.swift -> InformationRetrievalView.swift {
                #23707_16: #23707_16 = 35
                #23707_17: #23707_17 = 35
            }
            file:///Users/serhat/SW/balli/balli/Features/UserOnboarding/Views/UserSelectionView.swift -> UserSelectionView.swift {
                #2647_6: #2647_6 = Sonunda tanışabildik
            }
        ]
    }



== POWER STATE LOGS:

    11/4/2025, 11:27 Received power source state: Externally Powered
    11/4/2025, 11:27 No device power state user override user default value.Current power state: Full Power



== DISPLAYABLE CONTENT STATE:

    updateIdentifier: 68616
    buildingState: Paused: Process crashed
    isUpdateInProgress: false
    providers [
        Registry[Registry-ContentView.swift#1[preview] (line 128)] {
            status: Completed: Not attempted
        }
    ]
    registries [
        Registry-ContentView.swift#1[preview] {
            status: Completed: Available
            ContentView {
                canvasContent {
                    isStale: true
                    states {
                        livePreview: updating
                        staticPreview: disabled
                        Light Appearance: disabled
                        Dark Appearance: disabled
                        Portrait: disabled
                        Landscape Left: disabled
                        Landscape Right: disabled
                        X Small: disabled
                        Small: disabled
                        Medium: disabled
                        Large: disabled
                        X Large: disabled
                        XX Large: disabled
                        XXX Large: disabled
                        AX 1: disabled
                        AX 2: disabled
                        AX 3: disabled
                        AX 4: disabled
                        AX 5: disabled
                    }
                }
            }
        }
    ]


