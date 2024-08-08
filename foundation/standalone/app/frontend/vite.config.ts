import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

const askProxyUrl = process.env.ASK_PROXY_URL || "http://localhost:7071/";
const chatProxyUrl = process.env.CHAT_PROXY_URL || "http://localhost:7071/";
const uploadProxyUrl = process.env.UPLOAD_PROXY_URL || "http://localhost:7071/";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "./dist",
    emptyOutDir: true,
    sourcemap: true
},
  server: {
    proxy: {
      "/api/ask": askProxyUrl,
      "/api/chat": chatProxyUrl,
      "/api/upload": uploadProxyUrl
    }
  } 
})
