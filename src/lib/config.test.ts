import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { isValidUrl, resolveConfig } from "./config";

describe("isValidUrl", () => {
    it("accepts http:// URLs", () => {
        expect(isValidUrl("http://localhost:8000")).toBe(true);
        expect(isValidUrl("http://example.com")).toBe(true);
        expect(isValidUrl("http://192.168.1.1:3000/path")).toBe(true);
    });

    it("accepts https:// URLs", () => {
        expect(isValidUrl("https://example.com")).toBe(true);
        expect(isValidUrl("https://my.supabase.co")).toBe(true);
    });

    it("rejects URLs without http:// or https://", () => {
        expect(isValidUrl("ftp://example.com")).toBe(false);
        expect(isValidUrl("ws://example.com")).toBe(false);
        expect(isValidUrl("example.com")).toBe(false);
        expect(isValidUrl("")).toBe(false);
        expect(isValidUrl("not-a-url")).toBe(false);
        expect(isValidUrl("http//missing-colon.com")).toBe(false);
    });

    it("rejects protocol-only without content", () => {
        expect(isValidUrl("http://")).toBe(false);
        expect(isValidUrl("https://")).toBe(false);
    });
});

describe("resolveConfig", () => {
    let originalFetch: typeof globalThis.fetch;

    beforeEach(() => {
        originalFetch = globalThis.fetch;
        localStorage.clear();
        vi.stubEnv("VITE_SUPABASE_URL", "");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "");
    });

    afterEach(() => {
        globalThis.fetch = originalFetch;
        vi.unstubAllEnvs();
        localStorage.clear();
    });

    it("uses localStorage values when present (highest priority)", async () => {
        localStorage.setItem("supabaseUrl", "http://local-override:9000");
        localStorage.setItem("supabaseAnonKey", "local-key-123");

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
        expect(config.supabaseAnonKey).toBe("local-key-123");
    });

    it("uses config.json values when localStorage is empty", async () => {
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
        expect(config.supabaseUrl).toBe("http://config-json:8000");
        expect(config.supabaseAnonKey).toBe("config-key");
    });

    it("falls back to build-time env vars when config.json returns 404", async () => {
        const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => { });

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://build-time:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "build-key");

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://build-time:8000");
        expect(config.supabaseAnonKey).toBe("build-key");
        expect(warnSpy).toHaveBeenCalledWith(
            expect.stringContaining("config.json not found")
        );

        warnSpy.mockRestore();
    });

    it("falls back to build-time env vars on config.json parse error", async () => {
        const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => { });

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: () => Promise.reject(new Error("Invalid JSON")),
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://build-time:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "build-key");

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://build-time:8000");
        expect(config.supabaseAnonKey).toBe("build-key");
        expect(warnSpy).toHaveBeenCalledWith(
            expect.stringContaining("Failed to fetch or parse config.json"),
            expect.anything()
        );

        warnSpy.mockRestore();
    });

    it("falls back to build-time env vars when config.json has empty values", async () => {
        const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => { });

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: () =>
                Promise.resolve({
                    supabaseUrl: "",
                    supabaseAnonKey: "",
                }),
        });

        vi.stubEnv("VITE_SUPABASE_URL", "http://build-time:8000");
        vi.stubEnv("VITE_SUPABASE_ANON_KEY", "build-key");

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://build-time:8000");
        expect(config.supabaseAnonKey).toBe("build-key");

        warnSpy.mockRestore();
    });

    it("throws an error for invalid URL format", async () => {
        localStorage.setItem("supabaseUrl", "ftp://invalid-protocol.com");
        localStorage.setItem("supabaseAnonKey", "some-key");

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => { });

        await expect(resolveConfig()).rejects.toThrow(
            'Invalid Supabase URL: "ftp://invalid-protocol.com". The URL must start with http:// or https://.'
        );

        warnSpy.mockRestore();
    });

    it("returns empty strings when no config source is available", async () => {
        const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => { });

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
        });

        const config = await resolveConfig();
        expect(config.supabaseUrl).toBe("");
        expect(config.supabaseAnonKey).toBe("");

        warnSpy.mockRestore();
    });

    it("removes localStorage overrides and reverts to lower priority", async () => {
        localStorage.setItem("supabaseUrl", "http://override:9000");
        localStorage.setItem("supabaseAnonKey", "override-key");

        globalThis.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: () =>
                Promise.resolve({
                    supabaseUrl: "http://config-json:8000",
                    supabaseAnonKey: "config-key",
                }),
        });

        // First call uses localStorage
        let config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://override:9000");

        // Remove localStorage overrides
        localStorage.removeItem("supabaseUrl");
        localStorage.removeItem("supabaseAnonKey");

        // Second call falls back to config.json
        config = await resolveConfig();
        expect(config.supabaseUrl).toBe("http://config-json:8000");
        expect(config.supabaseAnonKey).toBe("config-key");
    });
});
