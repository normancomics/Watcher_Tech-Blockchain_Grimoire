"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { ChevronRight, ChevronDown, Folder, FolderOpen, FileCode, FileText, File } from "lucide-react"

type TreeNode = {
  name: string
  type: "folder" | "file"
  description?: string
  children?: TreeNode[]
}

const repoStructure: TreeNode = {
  name: "Watcher_Tech-Blockchain_Grimoire",
  type: "folder",
  children: [
    { name: "Structure", type: "file", description: "Master reference — full content hierarchy" },
    {
      name: "contracts",
      type: "folder",
      description: "⛓ Smart Contracts (Blockchain Layer)",
      children: [
        { name: "ArcanusMathematica.sol", type: "file", description: "ERC-721 NFT Grimoire" },
        { name: "AtlanteanDefenseVault.sol", type: "file", description: "7 defensive paradigms" },
        { name: "GoetiaGrimoire.sol", type: "file", description: "Watchers, Sages, Families registry" },
        { name: "OccultGrimoire.sol", type: "file", description: "Light/dark archetypes" },
        { name: "OccultKnowledgeAccess.sol", type: "file", description: "Hierarchical access" },
        { name: "vulnerability_contract.sol", type: "file", description: "Educational demo" },
      ],
    },
    {
      name: "scripts",
      type: "folder",
      description: "⚗ Execution Scripts (Python Layer)",
      children: [
        { name: "python_portal-solidity_ritual.py", type: "file", description: "Ritual validation & trigger" },
      ],
    },
    {
      name: "docs",
      type: "folder",
      description: "📜 Documentation & Lore",
      children: [
        { name: "core", type: "folder", description: "Foundation thesis & analysis" },
        { name: "codex", type: "folder", description: "Ritual-to-exploit reference" },
        { name: "languages", type: "folder", description: "Proto-Canaanite & steganography" },
        { name: "knowledge_tree", type: "folder", description: "7-level transmission mapping" },
        { name: "lineage", type: "folder", description: "Watcher-to-tech correspondence" },
      ],
    },
    {
      name: "13_Families",
      type: "folder",
      description: "🏛 The 13 Families Framework",
      children: [
        { name: "13_families.md", type: "file", description: "Families → Exploits → Defenses" },
        { name: "Domains", type: "folder", description: "Exploit archetypes" },
      ],
    },
    {
      name: "Atlantean",
      type: "folder",
      description: "🔱 Atlantean Framework",
      children: [
        { name: "7_Sages", type: "folder", description: "Nested hierarchical structure" },
      ],
    },
    {
      name: "mcp-server",
      type: "folder",
      description: "🔮 Grimoire Oracle MCP Server",
      children: [
        { name: "src", type: "folder", description: "TypeScript source" },
        { name: "README.md", type: "file", description: "Server documentation" },
      ],
    },
  ],
}

function TreeItem({ node, depth = 0 }: { node: TreeNode; depth?: number }) {
  const [isOpen, setIsOpen] = useState(depth < 1)
  const hasChildren = node.children && node.children.length > 0

  const getIcon = () => {
    if (node.type === "folder") {
      return isOpen ? (
        <FolderOpen className="w-4 h-4 text-primary" />
      ) : (
        <Folder className="w-4 h-4 text-primary/70" />
      )
    }
    if (node.name.endsWith(".sol")) return <FileCode className="w-4 h-4 text-chart-4" />
    if (node.name.endsWith(".md") || node.name.endsWith(".txt")) return <FileText className="w-4 h-4 text-chart-2" />
    if (node.name.endsWith(".py")) return <FileCode className="w-4 h-4 text-chart-5" />
    return <File className="w-4 h-4 text-muted-foreground" />
  }

  return (
    <div>
      <button
        onClick={() => hasChildren && setIsOpen(!isOpen)}
        className={`flex items-center gap-2 w-full text-left py-1.5 px-2 rounded hover:bg-muted/50 transition-colors ${
          hasChildren ? "cursor-pointer" : "cursor-default"
        }`}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
      >
        {hasChildren ? (
          isOpen ? (
            <ChevronDown className="w-3 h-3 text-muted-foreground shrink-0" />
          ) : (
            <ChevronRight className="w-3 h-3 text-muted-foreground shrink-0" />
          )
        ) : (
          <span className="w-3" />
        )}
        {getIcon()}
        <span className="font-mono text-sm truncate">{node.name}</span>
        {node.description && (
          <span className="text-xs text-muted-foreground truncate hidden sm:inline ml-2">
            {node.description}
          </span>
        )}
      </button>
      {isOpen && hasChildren && (
        <div>
          {node.children!.map((child, index) => (
            <TreeItem key={`${child.name}-${index}`} node={child} depth={depth + 1} />
          ))}
        </div>
      )}
    </div>
  )
}

export function RepoStructure() {
  return (
    <section id="structure" className="py-24 px-6 bg-card/30">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-primary text-2xl">📁</span>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Repository Structure
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            Explore the hierarchical organization of contracts, documentation, 
            and frameworks within the grimoire.
          </p>
        </div>

        <Card className="bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-destructive/50" />
              <div className="w-3 h-3 rounded-full bg-primary/50" />
              <div className="w-3 h-3 rounded-full bg-chart-4/50" />
              <span className="ml-2 text-sm text-muted-foreground">Click folders to expand</span>
            </div>
          </CardHeader>
          <CardContent className="p-4 max-h-[500px] overflow-y-auto">
            <TreeItem node={repoStructure} />
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
