import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // @ts-ignore
  allowedDevOrigins: ['pleasurably-endurant-maris.ngrok-free.dev', '10.242.107.183', '192.168.254.102', '192.168.254.102: 3000', 'localhost', 'localhost: 3000'],
  devIndicators: {
    appIsrStatus: false,
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Access-Control-Allow-Credentials", value: "true" },
          { key: "Access-Control-Allow-Origin", value: "*" },
          { key: "Access-Control-Allow-Methods", value: "GET,DELETE,PATCH,POST,PUT,OPTIONS" },
          { key: "Access-Control-Allow-Headers", value: "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization, ngrok-skip-browser-warning" },
        ]
      }
    ]
  }
};

export default nextConfig;
