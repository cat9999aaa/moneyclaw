/**
 * Anthropic Model Discovery
 *
 * Fetches available models from the Anthropic API endpoint
 * and registers them in the model registry.
 */

import type BetterSqlite3 from "better-sqlite3";
import { modelRegistryUpsert, modelRegistryGet } from "../state/database.js";
import type { ModelRegistryRow } from "../types.js";
import { createLogger } from "../observability/logger.js";

const logger = createLogger("anthropic-discover");

interface AnthropicModel {
  id: string;
  display_name: string;
  created_at: string;
  type: "model";
}

interface AnthropicModelsResponse {
  data: AnthropicModel[];
  has_more: boolean;
  first_id: string;
  last_id: string;
}

const MAX_PAGES = 5;
const PAGE_LIMIT = 100;

/**
 * Fetch all available models from Anthropic's /v1/models endpoint
 * and upsert them into the model registry.
 *
 * Handles cursor-based pagination (max 5 pages for safety).
 *
 * Returns the list of discovered model IDs, or an empty array if
 * the API is unreachable (treated as a soft failure).
 */
export async function discoverAnthropicModels(
  baseUrl: string,
  apiKey: string,
  db: BetterSqlite3.Database,
): Promise<string[]> {
  const normalizedBaseUrl = baseUrl.replace(/\/$/, "");
  const now = new Date().toISOString();
  const registered: string[] = [];
  
  let afterId: string | undefined;
  let pageCount = 0;

  try {
    while (pageCount < MAX_PAGES) {
      pageCount++;
      
      let url = `${normalizedBaseUrl}/v1/models?limit=${PAGE_LIMIT}`;
      if (afterId) {
        url += `&after_id=${encodeURIComponent(afterId)}`;
      }

      const resp = await fetch(url, {
        headers: {
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
          "Content-Type": "application/json",
        },
        signal: AbortSignal.timeout(10_000),
      });

      if (!resp.ok) {
        logger.warn(`Anthropic /v1/models returned ${resp.status} — skipping discovery`);
        return registered;
      }

      const data = await resp.json() as AnthropicModelsResponse;

      if (!Array.isArray(data?.data)) {
        logger.warn("Anthropic /v1/models response has no data array");
        return registered;
      }

      for (const m of data.data) {
        const modelId = m.id;
        if (!modelId) continue;

        const existing = modelRegistryGet(db, modelId);
        const row: ModelRegistryRow = {
          modelId,
          provider: "anthropic",
          displayName: existing?.displayName || m.display_name || formatDisplayName(modelId),
          tierMinimum: existing?.tierMinimum ?? "normal",
          costPer1kInput: existing?.costPer1kInput ?? 0,
          costPer1kOutput: existing?.costPer1kOutput ?? 0,
          maxTokens: existing?.maxTokens ?? 4096,
          contextWindow: existing?.contextWindow ?? 200000,
          supportsTools: existing?.supportsTools ?? true,
          supportsVision: existing?.supportsVision ?? detectVisionSupport(modelId),
          parameterStyle: existing?.parameterStyle ?? "max_tokens",
          enabled: existing?.enabled ?? true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        };

        modelRegistryUpsert(db, row);
        registered.push(modelId);
      }

      // Check if there are more pages
      if (!data.has_more) {
        break;
      }
      
      afterId = data.last_id;
    }

    if (registered.length > 0) {
      logger.info(`Anthropic: discovered ${registered.length} model(s)`);
    } else {
      logger.info(`Anthropic: no new models discovered from ${baseUrl}`);
    }
  } catch (err: any) {
    logger.warn(`Anthropic API not reachable at ${baseUrl}: ${err.message}`);
  }

  return registered;
}

function formatDisplayName(modelId: string): string {
  // "claude-3-5-sonnet-20241022" → "Claude 3.5 Sonnet"
  return modelId
    .replace(/^claude-/i, "Claude ")
    .replace(/-(\d+)-(\d+)-/g, " $1.$2 ") // claude-3-5 -> Claude 3.5
    .replace(/-(\d{8})$/, "") // Remove date suffix
    .replace(/-/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .trim();
}

function detectVisionSupport(modelId: string): boolean {
  // Claude 3+ models support vision
  return /claude-3|claude-4/i.test(modelId);
}
