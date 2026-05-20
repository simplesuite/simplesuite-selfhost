import { describe, it, expect } from "vitest";
import * as fc from "fast-check";
import { isValidUrl } from "./config";

/**
 * Property 8: Invalid URL rejection
 * Validates: Requirements 6.4
 *
 * For any string that is not a valid HTTP or HTTPS URL (e.g., missing protocol,
 * ftp://, empty string, malformed), the frontend SHALL reject it as a
 * SUPABASE_PUBLIC_URL configuration and SHALL NOT attempt to initialize
 * supabase-js with that value.
 */
describe("Property 8: Invalid URL rejection", () => {
    it("rejects any string that is not a valid http:// or https:// URL", () => {
        // Generator for strings that are definitively NOT valid http/https URLs.
        // A valid URL per isValidUrl is: starts with http:// or https:// followed by 1+ chars.
        const invalidUrlArb = fc.oneof(
            // Empty string
            fc.constant(""),
            // Protocol-only without content after ://
            fc.constantFrom("http://", "https://"),
            // Other protocols (ftp, ws, file, etc.)
            fc.string({ minLength: 1 }).map((s) => `ftp://${s}`),
            fc.string({ minLength: 1 }).map((s) => `ws://${s}`),
            fc.string({ minLength: 1 }).map((s) => `wss://${s}`),
            fc.string({ minLength: 1 }).map((s) => `file://${s}`),
            // Malformed protocols (missing colon or slashes)
            fc.string({ minLength: 1 }).map((s) => `http/${s}`),
            fc.string({ minLength: 1 }).map((s) => `http:/${s}`),
            fc.string({ minLength: 1 }).map((s) => `https/${s}`),
            fc.string({ minLength: 1 }).map((s) => `https:/${s}`),
            fc.string({ minLength: 1 }).map((s) => `http${s}`).filter(
                (s) => !s.startsWith("http://") && !s.startsWith("https://")
            ),
            // Random strings that don't start with http:// or https://
            fc.string({ minLength: 1 }).filter(
                (s) => !s.startsWith("http://") && !s.startsWith("https://")
            ),
            fc.constantFrom(
                "example.com",
                "localhost:8000",
                "not-a-url",
                "://missing-protocol.com",
                "htp://typo.com"
            )
        );

        fc.assert(
            fc.property(invalidUrlArb, (invalidUrl) => {
                expect(isValidUrl(invalidUrl)).toBe(false);
            }),
            { numRuns: 100 }
        );
    });

    it("accepts any valid http:// or https:// URL with content after the protocol", () => {
        // Generator for valid http/https URLs (protocol + at least one character)
        const validUrlArb = fc.oneof(
            fc.string({ minLength: 1 }).map((s) => `http://${s}`),
            fc.string({ minLength: 1 }).map((s) => `https://${s}`)
        );

        fc.assert(
            fc.property(validUrlArb, (validUrl) => {
                expect(isValidUrl(validUrl)).toBe(true);
            }),
            { numRuns: 100 }
        );
    });
});
