import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { hostname: 'i.ytimg.com' },
      { hostname: 'yt3.ggpht.com' },
      { hostname: 'yt3.googleusercontent.com' },
    ],
  },
}

export default nextConfig
