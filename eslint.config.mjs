import nextConfig from "eslint-config-next"

const eslintConfig = [
  ...nextConfig,
  {
    ignores: ["08_MCP_Sovereign_Oracle/mcp_server/**", "public/**"],
  },
]

export default eslintConfig
