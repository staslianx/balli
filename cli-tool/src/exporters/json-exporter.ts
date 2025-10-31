import * as fs from 'fs';
import { ResearchJourney } from '../types/research-journey';

export class JSONExporter {
  /**
   * Export journey to JSON file
   */
  export(journey: ResearchJourney, filepath: string): void {
    try {
      const json = JSON.stringify(journey, null, 2);
      fs.writeFileSync(filepath, json, 'utf-8');
      console.log(`\n💾 JSON report saved to: ${filepath}`);
    } catch (error) {
      console.error(`Error exporting JSON: ${error}`);
      throw error;
    }
  }

  /**
   * Load journey from JSON file
   */
  load(filepath: string): ResearchJourney {
    try {
      const content = fs.readFileSync(filepath, 'utf-8');
      return JSON.parse(content) as ResearchJourney;
    } catch (error) {
      console.error(`Error loading JSON: ${error}`);
      throw error;
    }
  }
}
