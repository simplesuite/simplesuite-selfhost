import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { getSupabaseClient, resetSupabaseClient } from "./supabase";
import { resolveConfig } from "./config";

describe("supabase client initialization", () => {
    let originalFetch: typeof globalThis.fetch;

    beforeEach(() => {
        originalFetch = globalThis.fetch;
        localStorage.clear();
        resetSupabaseClient();
        vi.stubEnv("VITE_SUPABASE_URL", "");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "");
    });

    afterEach(() => {
        globalThis.fetch = originalFetch;
        vi.unstubAllEnvs();
    });

    it("creates a client using build-time env vars as fallback", async () => {
        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://localhost:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "test-anon-key");

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://localhost:8000");

        resetSupabaseClient();
        const client = await getSupabaseClient();
        expect(client).toBeDefined();
    });

    it("creates a client using config.json values", async () => {
        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: () =>
                Promise.resolve({
                    supabaseUrl: "http://self-hosted:8000",
                    supabaseAnonKey: "runtime-key",
                }),
        });

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://self-hosted:8000");

        resetSupabaseClient();
        const client = await getSupabaseClient();
        expect(client).toBeDefined();
    });

    it("creates a client using localStorage overrides (highest priority)", async () => {
        localStorage.setItem("supabaseUrl", "http://local-override:9000");
        localStorage.setItem("supabaseAnonKey", "local-key");

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: () =>
                Promise.resolve({
                    supabaseUrl: "http://config-json:8000",
                    supabaseAnonKey: "config-key",
                }),
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://build-time:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "build-key");

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://local-override:9000");

        resetSupabaseClient();
        const client = await getSupabaseClient();
        expect(client).toBeDefined();
    });

    it("returns the same cached instance on subsequent calls", async () => {
        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://localhost:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "test-key");

        const client1 = await getSupabaseClient();
        const client2 = await getSupabaseClient();
        expect(client1).toBe(client2);
    });

    it("throws when configuration is incomplete (no URL or key)", async () => {
        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        await expect(getSupabaseClient()).rejects.toThrow(
            "Supabase configuration is incomplete"
        );
    });

    it("throws when URL is invalid format", async () => {
        localStorage.setItem("supabaseUrl", "ftp://bad-protocol.com");
        localStorage.setItem("supabaseAnonKey", "some-key");

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        await expect(getSupabaseClient()).rejects.toThrow(
            "Invalid Supabase URL"
        );
    });

    it("resets cached instance when resetSupabaseClient is called", async () => {
        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://localhost:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "test-key");

        const client1 = await getSupabaseClient();

        resetSupabaseClient();

        vi.stubEnv("VITE_SUPABASE_URL", "http://different:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "different-key");

        const client2 = await getSupabaseClient();
        expect(client1).not.toBe(client2);
    });
});
