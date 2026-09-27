// `signInWithPopup` needs the opener relationship intact, so COOP is
// same-origin-allow-popups rather than the stricter same-origin — the latter
// severs window.opener and breaks the Google sign-in flow.
const securityHeaders: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000",
  "Cross-Origin-Opener-Policy": "same-origin-allow-popups",
  "Permissions-Policy":
    "accelerometer=(), autoplay=(self), camera=(), display-capture=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=()",
};

// Vite's dev client relies on eval and injected styles, so the CSP is attached
// to production builds only — otherwise `pnpm dev` loses HMR.
if (process.env.NODE_ENV === "production") {
  securityHeaders["Content-Security-Policy"] = [
    "default-src 'self'",
    "base-uri 'self'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "form-action 'self'",
    // Arbitrary https: because resource thumbnails and profile photos are served
    // from user-controlled Storage paths, not just *.googleapis.com.
    "img-src 'self' data: blob: https:",
    "font-src 'self' data:",
    // UnoCSS and Vue SFC styles are injected as inline <style> at runtime.
    "style-src 'self' 'unsafe-inline'",
    // Nuxt inlines the entry + payload scripts. No 'unsafe-eval' — the Vue
    // runtime-only build does not need it.
    "script-src 'self' 'unsafe-inline'",
    "connect-src 'self' https://*.googleapis.com wss://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.run.app https://api.iconify.design https://api.simplesvg.com https://api.unisvg.com",
    "frame-src 'self' https://*.firebaseapp.com https://accounts.google.com https://auth.firebase.google.com",
    "worker-src 'self' blob:",
    "manifest-src 'self'",
    "upgrade-insecure-requests",
  ].join("; ");
}

export default defineNuxtConfig({
  compatibilityDate: "2024-10-24",
  ssr: false,
  srcDir: "app",
  modules: [
    "@vueuse/nuxt",
    "@nuxt/icon",
    "@unocss/nuxt",
    "@nuxt/eslint",
    "@pinia/nuxt",
    "pinia-plugin-persistedstate/nuxt",
  ],
  devtools: { enabled: true },
  css: ["./app/app.css"],
  unocss: { nuxtLayers: true },
  imports: { dirs: ["./stores"] },
  routeRules: {
    "/**": { headers: securityHeaders },
  },
  runtimeConfig: {
    public: {
      apiBaseUrl: "",
      firebaseApiKey: "",
      firebaseAuthDomain: "",
      firebaseProjectId: "",
      firebaseAppId: "",
    },
  },
});
