/**
 * Supabase Client Initialization
 *
 * Uses the configuration resolver to initialize supabase-js with the
 * correct connection details based on the priority chain:
 *   localStorage → config.json → build-time env vars
 *
 * The client is lazily initialized on first use via getSupabaseClient().
 * This ensures the async config resolution (which fetches config.json)
 * completes before the client is created.
 *
 * Validates: Requirements 8.1, 8.2, 8.3, 8.4
 */

import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { resolveConfig } from "./config";

let clientInstance: SupabaseClient | null = null;
let clientPromise: Promise<SupabaseClient> | null = null;

/**
 * Returns the initialized Supabase client.
 *
 * On first call, resolves configuration and creates the client.
 * Subsequent calls return the same cached instance.
 *
 * Throws if the resolved configuration has an invalid URL.
 */
export async function getSupabaseClient(): Promise<SupabaseClient> {
    if (clientInstance) {
        return clientInstance;
    }

    // Deduplicate concurrent initialization calls
    if (!clientPromise) {
        clientPromise = initializeClient();
    }

    return clientPromise;
}

async function initializeClient(): Promise<SupabaseClient> {
    const config = await resolveConfig();

    if (!config.supabaseUrl || !config.supabaseAnonKey) {
        throw new Error(
            "Supabase configuration is incomplete. Ensure supabaseUrl and supabaseAnonKey are provided via localStorage, config.json, or build-time environment variables."
        );
    }

    clientInstance = createClient(config.supabaseUrl, config.supabaseAnonKey);
    return clientInstance;
}

/**
 * Resets the cached client instance.
 * Useful for testing or when configuration changes (e.g., localStorage update).
 */
export function resetSupabaseClient(): void {
    clientInstance = null;
    clientPromise = null;
}
