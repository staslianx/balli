import * as fs from 'fs';
import * as path from 'path';
import { Config } from '../types/research-journey';

const DEFAULT_CONFIG: Config = {
  firebaseFunctions: {
    emulator: true,
    emulatorUrl: 'http://127.0.0.1:5001/balli-health/us-central1/diabetesAssistantStream',
    projectId: 'balli-health',
    region: 'us-central1'
  },
  display: {
    colorScheme: 'default',
    verbosity: 'normal',
    showTimestamps: true,
    showCosts: true,
    showTokens: true
  },
  export: {
    autoSave: true,
    outputDir: './research-logs',
    formats: ['json', 'markdown']
  }
};

export class ConfigLoader {
  private config: Config;

  constructor(configPath?: string) {
    this.config = this.loadConfig(configPath);
  }

  private loadConfig(configPath?: string): Config {
    // Try to load from provided path
    if (configPath && fs.existsSync(configPath)) {
      return this.mergeWithDefaults(this.readConfigFile(configPath));
    }

    // Try to load from current directory
    const localPath = path.join(process.cwd(), 'research-xray.config.json');
    if (fs.existsSync(localPath)) {
      return this.mergeWithDefaults(this.readConfigFile(localPath));
    }

    // Try to load from home directory
    const homePath = path.join(process.env.HOME || '~', '.research-xray.config.json');
    if (fs.existsSync(homePath)) {
      return this.mergeWithDefaults(this.readConfigFile(homePath));
    }

    // Use defaults
    return DEFAULT_CONFIG;
  }

  private readConfigFile(filePath: string): Partial<Config> {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      return JSON.parse(content);
    } catch (error) {
      console.error(`Error reading config file ${filePath}:`, error);
      return {};
    }
  }

  private mergeWithDefaults(partial: Partial<Config>): Config {
    return {
      ...DEFAULT_CONFIG,
      ...partial,
      firebaseFunctions: {
        ...DEFAULT_CONFIG.firebaseFunctions,
        ...partial.firebaseFunctions
      },
      display: {
        ...DEFAULT_CONFIG.display,
        ...partial.display
      },
      export: {
        ...DEFAULT_CONFIG.export,
        ...partial.export
      }
    };
  }

  getConfig(): Config {
    return this.config;
  }

  getFirebaseUrl(): string {
    if (this.config.firebaseFunctions.emulator) {
      return this.config.firebaseFunctions.emulatorUrl || DEFAULT_CONFIG.firebaseFunctions.emulatorUrl!;
    }
    return this.config.firebaseFunctions.productionUrl ||
      `https://${this.config.firebaseFunctions.region}-${this.config.firebaseFunctions.projectId}.cloudfunctions.net/diabetesAssistantStream`;
  }

  ensureOutputDir(): void {
    const dir = this.config.export.outputDir;
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  generateOutputFilename(extension: string): string {
    const now = new Date();
    const timestamp = now.toISOString().replace(/:/g, '-').replace(/\..+/, '').replace('T', '_');
    return path.join(this.config.export.outputDir, `research_${timestamp}.${extension}`);
  }
}
