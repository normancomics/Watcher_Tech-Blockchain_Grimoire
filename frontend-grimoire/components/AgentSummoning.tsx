/**
 * @title AgentSummoning — Agent Deployment UI
 * @notice React component for summoning/deploying sovereign agents
 */

'use client';

import React, { useState } from 'react';

type AgentType = 'watcher-archon' | 'lunar-oracle' | 'exploit-hunter';

interface AgentConfig {
  type: AgentType;
  name: string;
  icon: string;
  description: string;
  minBondEth: number;
  capabilities: string[];
}

const AVAILABLE_AGENTS: AgentConfig[] = [
  {
    type: 'watcher-archon',
    name: 'Watcher Archon',
    icon: '👁️',
    description: 'Supreme guardian — coordinates the full swarm and monitors all threats',
    minBondEth: 2.0,
    capabilities: ['EXPLOIT_DETECT', 'SWARM_COORD', 'BLOCKCHAIN_DIVINATION'],
  },
  {
    type: 'lunar-oracle',
    name: 'Lunar Oracle',
    icon: '🌙',
    description: 'Celestial specialist — monitors moon phases and risk windows',
    minBondEth: 0.5,
    capabilities: ['LUNAR_CALC'],
  },
  {
    type: 'exploit-hunter',
    name: 'Exploit Hunter',
    icon: '🔍',
    description: 'Security specialist — detects Qliphotic attack patterns in real-time',
    minBondEth: 1.0,
    capabilities: ['EXPLOIT_DETECT'],
  },
];

export function AgentSummoning(): React.ReactElement {
  const [selectedAgent, setSelectedAgent] = useState<AgentType | null>(null);
  const [bondAmount, setBondAmount] = useState('');
  const [summoning, setSummoning] = useState(false);
  const [summonedAgents, setSummonedAgents] = useState<AgentType[]>([]);

  const selectedConfig = AVAILABLE_AGENTS.find(a => a.type === selectedAgent);

  const handleSummon = async () => {
    if (!selectedConfig) return;
    const bond = parseFloat(bondAmount);
    if (bond < selectedConfig.minBondEth) {
      alert(`Minimum bond: ${selectedConfig.minBondEth} ETH`);
      return;
    }
    
    setSummoning(true);
    await new Promise(r => setTimeout(r, 2000));  // Simulate transaction
    setSummonedAgents(prev => [...prev, selectedConfig.type]);
    setSummoning(false);
    setBondAmount('');
    setSelectedAgent(null);
  };

  return (
    <div className="agent-summoning p-6 bg-gray-900 text-purple-300 rounded-lg border border-purple-700">
      <h2 className="text-2xl font-bold mb-6 text-purple-200">🔮 Agent Summoning Chamber</h2>
      
      <div className="grid gap-3 mb-6">
        {AVAILABLE_AGENTS.map(agent => (
          <button
            key={agent.type}
            onClick={() => setSelectedAgent(agent.type)}
            className={`p-4 rounded-lg border text-left transition-colors ${
              selectedAgent === agent.type
                ? 'border-purple-400 bg-purple-900/30'
                : 'border-purple-800 hover:border-purple-600'
            }`}
          >
            <div className="flex items-center gap-3">
              <span className="text-3xl">{agent.icon}</span>
              <div>
                <p className="font-bold text-purple-200">{agent.name}</p>
                <p className="text-xs text-purple-400">{agent.description}</p>
                <p className="text-xs text-purple-500 mt-1">Min bond: {agent.minBondEth} ETH</p>
              </div>
              {summonedAgents.includes(agent.type) && (
                <span className="ml-auto text-green-400">✓ Active</span>
              )}
            </div>
          </button>
        ))}
      </div>
      
      {selectedConfig && (
        <div className="border border-purple-600 rounded p-4">
          <h3 className="font-bold text-purple-200 mb-3">Summon {selectedConfig.name}</h3>
          <div className="mb-3">
            <label className="block text-sm mb-1">Bond Amount (ETH)</label>
            <input
              type="number"
              value={bondAmount}
              onChange={e => setBondAmount(e.target.value)}
              min={selectedConfig.minBondEth}
              step="0.1"
              placeholder={`Min: ${selectedConfig.minBondEth} ETH`}
              className="w-full p-2 bg-gray-800 border border-purple-600 rounded"
            />
          </div>
          <button
            onClick={handleSummon}
            disabled={summoning}
            className="w-full py-2 bg-purple-700 hover:bg-purple-600 disabled:bg-gray-700 rounded font-bold"
          >
            {summoning ? '⏳ Summoning...' : `${selectedConfig.icon} Summon Agent`}
          </button>
        </div>
      )}
    </div>
  );
}

export default AgentSummoning;
