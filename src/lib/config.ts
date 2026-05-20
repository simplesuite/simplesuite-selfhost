/**
 * Frontend Configuration Resolver
 *
 * Resolves Supabase connection details using a priority chain:
 *   1. localStorage overrides ("supabaseUrl", "supabaseAnonKey")
 *   2. Runtime config.json (fetched from server root)
 *   3. Build-time environment variables (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)
 *
 * Validates: Requirements 5.2, 5.3, 5.4, 5.6, 6.1, 6.2, 6.3, 6.4, 6.5
 */

export interface ResolvedConfig {
    supabaseUrl: string;
    supabaseAnonKey: string;
}

interface RuntimeConfig {
    supabaseUrl?: string;
    supabaseAnonKey?: string;
}

/**
 * Validates that a URL string starts with http:// or https://.
 * Returns true if valid, false otherwise.
 */
export function isValidUrl(url: string): boolean {
    return /^https?:\/\/.+/.test(url);
}

/**
 * Fetches and parses config.json from the server root.
 * Returns null on 404 or parse error (with a console warning).
 */
async function fetchRuntimeConfig(): Promise<RuntimeConfig | null> {
    try {
        const response = await fetch("/config.json");

        if (!response.ok) {
            if (response.status === 404) {
                console.warn("[config] config.json not found, falling back to build-time variables.");
            } else {
                console.warn(`[config] config.json returned status ${response.status}, falling back to build-time variables.`);
            }
            return null;
        }

        const data: unknown = await response.json();

        if (typeof data !== "object" || data === null) {
            console.warn("[config] config.json contains invalid data, falling back to build-time variables.");
            return null;
        }

        return data as RuntimeConfig;
    } catch (error) {
        console.warn("[config] Failed to fetch or parse config.json, falling back to build-time variables.", error);
        return null;
    }
}

/**
 * Resolves Supabase configuration using the priority chain:
 *   localStorage → config.json → build-time env vars
 *
 * Throws an error with a user-facing message if the resolved URL is invalid.
 */
export async function resolveConfig(): Promise<ResolvedConfig> {
    // Priority 1: localStorage overrides
    const localUrl = localStorage.getItem("supabaseUrl");
    const localKey = localStorage.getItem("supabaseAnonKey");

    // Priority 2: Runtime config.json
    const runtimeConfig = await fetchRuntimeConfig();

    // Priority 3: Build-time environment variables
    const buildUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
    const buildKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

    // Resolve using priority chain
    const supabaseUrl =
        (localUrl && localUrl.trim()) ||
        (runtimeConfig?.supabaseUrl && runtimeConfig.supabaseUrl.trim()) ||
        (buildUrl && buildUrl.trim()) ||
        "";

    const supabaseAnonKey =
        (localKey && localKey.trim()) ||
        (runtimeConfig?.supabaseAnonKey && runtimeConfig.supabaseAnonKey.trim()) ||
        (buildKey && buildKey.trim()) ||
        "";

    // Validate URL format
    if (supabaseUrl && !isValidUrl(supabaseUrl)) {
        throw new Error(
            `Invalid Supabase URL: "${supabaseUrl}". The URL must start with http:// or https://.`
        );
    }

    return { supabaseUrl, supabaseAnonKey };
}
