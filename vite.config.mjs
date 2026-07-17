import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { basicAuthApi } from "./scripts/basic-auth.mjs";
import { wardrobeImportApi } from "./scripts/import-job-api.mjs";
import { responsiveImageApi } from "./scripts/responsive-image-api.mjs";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  return {
    optimizeDeps: {
      include: ["react", "react-dom/client"],
    },
    server: {
      host: "0.0.0.0",
      allowedHosts: ["terminal.local"],
      warmup: {
        clientFiles: ["./src/main.jsx"],
      },
    },
    preview: {
      host: "0.0.0.0",
      port: Number(process.env.PORT) || 4173,
      allowedHosts: true,
    },
    plugins: [basicAuthApi({ env }), react(), responsiveImageApi(), wardrobeImportApi({ env })],
  };
});
