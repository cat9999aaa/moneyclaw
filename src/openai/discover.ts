/**
 * OpenAI Model Discovery
 *
 * Fetches available models from an OpenAI-compatible API endpoint
 * and registers them in the model registry.
 */

import type BetterSqlite3 from "better-sqlite3";
import { modelRegistryUpsert, modelRegistryGet, modelRegistryGetAll, modelRegistrySetEnabled } from "../state/database.js";
import type { ModelRegistryRow } from "../types.js";
import { createLogger } from "../observability/logger.js";

const logger = createLogger("openai-discover");

interface OpenAIModel {
  id: string;
  object: string;
  created: number;
  owned_by: string;
}

interface OpenAIModelsResponse {
  object: "list";
  data: OpenAIModel[];
}

// Regex to match chat completion models (exclude embeddings, DALL-E, whisper, TTS, fine-tuned)
const CHAT_MODEL_PATTERN = /^(gpt-|o[13][-.]|o[13]$|chatgpt-)/i;
const EXCLUDE_PATTERN = /^(dall-e|whisper|tts|text-embedding|ft:|babbage|davinci|curie|ada)/i;

/**
 * Fetch all available models from an OpenAI-compatible /v1/models endpoint
 * and upsert them into the model registry.
 *
 * For stock OpenAI (api.openai.com), filters to chat models only.
 * For custom base URLs (OpenAI-compatible providers), includes all models.
 *
 * Returns the list of discovered model IDs, or an empty array if
 * the API is unreachable (treated as a soft failure).
 */
export async function discoverOpenAIModels(
  baseUrl: string,
  apiKey: string,
  db: BetterSqlite3.Database,
): Promise<string[]> {
  const normalizedBaseUrl = baseUrl.replace(/\/$/, "");
  const url = `${normalizedBaseUrl}/v1/models`;
  const isStockOpenAI = normalizedBaseUrl.includes("api.openai.com");

  let data: OpenAIModelsResponse;
  try {
    const resp = await fetch(url, {
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(10_000),
    });

    if (!resp.ok) {
      logger.warn(`OpenAI /v1/models returned ${resp.status} — skipping discovery`);
      return [];
    }

    data = await resp.json() as OpenAIModelsResponse;
  } catch (err: any) {
    logger.warn(`OpenAI API not reachable at ${baseUrl}: ${err.message}`);
    return [];
  }

  if (!Array.isArray(data?.data)) {
    logger.warn("OpenAI /v1/models response has no data array");
    return [];
  }

  const now = new Date().toISOString();
  const registered: string[] = [];
  const discovered = new Set<string>();

  for (const m of data.data) {
    const modelId = m.id;
    if (!modelId) continue;

    // For stock OpenAI, filter to chat models only
    if (isStockOpenAI) {
      if (!CHAT_MODEL_PATTERN.test(modelId) || EXCLUDE_PATTERN.test(modelId)) {
        continue;
      }
    }

    const existing = modelRegistryGet(db, modelId);
    const row: ModelRegistryRow = {
      modelId,
      provider: "openai",
      displayName: existing?.displayName || formatDisplayName(modelId),
      tierMinimum: existing?.tierMinimum ?? "normal",
      costPer1kInput: existing?.costPer1kInput ?? 0,
      costPer1kOutput: existing?.costPer1kOutput ?? 0,
      maxTokens: existing?.maxTokens ?? 4096,
      contextWindow: existing?.contextWindow ?? 128000,
      supportsTools: existing?.supportsTools ?? true,
      supportsVision: existing?.supportsVision ?? detectVisionSupport(modelId),
      parameterStyle: existing?.parameterStyle ?? "max_completion_tokens",
      enabled: existing?.enabled ?? true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };

    modelRegistryUpsert(db, row);
    registered.push(modelId);
    discovered.add(modelId);
  }

  if (discovered.size > 0) {
    const existingRows = modelRegistryGetAll(db);
    for (const row of existingRows) {
      if (row.provider !== "openai") continue;
      if (discovered.has(row.modelId)) continue;
      if (!row.enabled) continue;
      modelRegistrySetEnabled(db, row.modelId, false);
    }
  }

  if (registered.length > 0) {
    logger.info(`OpenAI: discovered ${registered.length} model(s)`);
  } else {
    logger.info(`OpenAI: no new models discovered from ${baseUrl}`);
  }

  return registered;
}

function formatDisplayName(modelId: string): string {
  // "gpt-4.1-mini" → "GPT-4.1 Mini"
  return modelId
    .replace(/^gpt-/i, "GPT-")
    .replace(/^o([13])/i, "O$1")
    .replace(/^chatgpt-/i, "ChatGPT-")
    .replace(/-/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .replace(/(\d)\.(\d)/g, "$1.$2"); // Preserve version numbers
}

function detectVisionSupport(modelId: string): boolean {
  // Models known to support vision
  return /gpt-4o|gpt-4-turbo|gpt-4-vision|o[13]/i.test(modelId);
}
