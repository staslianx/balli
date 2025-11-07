/**
 * Jest Test Setup
 * Configures mocks for Firebase Admin and Genkit
 */

import { jest } from '@jest/globals';

// Mock Firebase Admin before any imports
jest.mock('firebase-admin/firestore', () => {
  const mockCollection = jest.fn();
  const mockDoc = jest.fn();
  const mockGet = jest.fn();
  const mockSet = jest.fn();
  const mockAdd = jest.fn();
  const mockWhere = jest.fn();
  const mockLimit = jest.fn();
  const mockFindNearest = jest.fn();
  const mockBatch = jest.fn();
  const mockCount = jest.fn();

  return {
    getFirestore: jest.fn(() => ({
      collection: mockCollection,
      batch: mockBatch
    })),
    FieldValue: {
      serverTimestamp: jest.fn(() => new Date())
    },
    __mockCollection: mockCollection,
    __mockDoc: mockDoc,
    __mockGet: mockGet,
    __mockSet: mockSet,
    __mockAdd: mockAdd,
    __mockWhere: mockWhere,
    __mockLimit: mockLimit,
    __mockFindNearest: mockFindNearest,
    __mockBatch: mockBatch,
    __mockCount: mockCount
  };
});

// Mock Genkit instance
jest.mock('../genkit-instance', () => ({
  ai: {
    generate: jest.fn(),
    embed: jest.fn(),
    createSession: jest.fn(),
    loadSession: jest.fn()
  }
}));

// Mock providers
jest.mock('../providers', () => ({
  getClassifierModel: jest.fn(() => 'gemini-1.5-flash'),
  getEmbedder: jest.fn(() => 'text-embedding-004'),
  getTier1Model: jest.fn(() => 'gemini-2.5-flash'),
  getTier3Model: jest.fn(() => 'gemini-2.5-flash'),
  getNutritionCalculatorModel: jest.fn(() => 'gemini-2.5-pro')
}));

// Suppress console logs during tests (optional)
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
};
