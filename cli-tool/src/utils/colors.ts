import chalk from 'chalk';
import gradient from 'gradient-string';

/**
 * Color palette for visual consistency
 */
export const colors = {
  // System stages
  system: chalk.blue,
  systemBold: chalk.blue.bold,

  // Success states
  success: chalk.green,
  successBold: chalk.green.bold,

  // Decisions and reasoning
  decision: chalk.yellow,
  decisionBold: chalk.yellow.bold,

  // Errors and warnings
  error: chalk.red,
  errorBold: chalk.red.bold,
  warning: chalk.yellow,

  // Cost and metrics
  metric: chalk.magenta,
  metricBold: chalk.magenta.bold,

  // Metadata
  meta: chalk.gray,
  metaBold: chalk.gray.bold,

  // User input/output
  user: chalk.cyan,
  userBold: chalk.cyan.bold,

  // Highlights
  highlight: chalk.white.bold,
  dim: chalk.dim,

  // Tier colors
  tier0: chalk.gray,
  tier1: chalk.blue,
  tier2: chalk.cyan,
  tier3: chalk.magenta,

  // Response streaming
  response: chalk.white
};

/**
 * Gradient text effects
 */
export const gradients = {
  rainbow: gradient('cyan', 'magenta', 'yellow'),
  ocean: gradient('cyan', 'blue'),
  fire: gradient('yellow', 'red'),
  success: gradient('green', 'cyan'),
  warning: gradient('yellow', 'orange', 'red')
};

/**
 * Box drawing characters
 */
export const box = {
  topLeft: '┌',
  topRight: '┐',
  bottomLeft: '└',
  bottomRight: '┘',
  horizontal: '─',
  vertical: '│',
  verticalRight: '├',
  verticalLeft: '┤',
  horizontalDown: '┬',
  horizontalUp: '┴',
  cross: '┼'
};

/**
 * Progress bar characters
 */
export const progressChars = {
  filled: '█',
  halfFilled: '▓',
  quarterFilled: '░',
  empty: '░'
};

/**
 * Icons
 */
export const icons = {
  success: '✓',
  error: '✗',
  warning: '⚠',
  info: 'ℹ',
  search: '🔍',
  docs: '📚',
  clock: '⏱',
  money: '💰',
  rocket: '🚀',
  brain: '🧠',
  chart: '📊',
  trophy: '🏆',
  microscope: '🔬',
  fire: '🔥',
  target: '🎯',
  star: '⭐',
  check: '✅',
  cross: '❌',
  arrow: '→',
  arrowRight: '→',
  arrowDown: '↓',
  bullet: '•'
};

/**
 * Format percentage
 */
export function formatPercentage(value: number): string {
  return `${value.toFixed(1)}%`;
}

/**
 * Format duration in human-readable format
 */
export function formatDuration(ms: number): string {
  if (ms < 1000) {
    return `${ms}ms`;
  }
  const seconds = (ms / 1000).toFixed(2);
  return `${seconds}s`;
}

/**
 * Format cost in dollars
 */
export function formatCost(cost: number): string {
  return `$${cost.toFixed(6)}`;
}

/**
 * Format token count with commas
 */
export function formatTokens(tokens: number): string {
  return tokens.toLocaleString();
}

/**
 * Create a progress bar
 */
export function createProgressBar(percentage: number, width: number = 20): string {
  const filled = Math.round((percentage / 100) * width);
  const empty = width - filled;
  return colors.success(progressChars.filled.repeat(filled)) +
         colors.meta(progressChars.empty.repeat(empty));
}

/**
 * Create a horizontal line
 */
export function createLine(width: number = 60, char: string = box.horizontal): string {
  return char.repeat(width);
}

/**
 * Center text in a given width
 */
export function centerText(text: string, width: number): string {
  const padding = Math.max(0, Math.floor((width - text.length) / 2));
  return ' '.repeat(padding) + text;
}

/**
 * Pad text to a specific width
 */
export function padText(text: string, width: number): string {
  if (text.length >= width) return text;
  return text + ' '.repeat(width - text.length);
}

/**
 * Truncate text with ellipsis
 */
export function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength - 3) + '...';
}
