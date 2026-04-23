/**
 * @title Agents — Agent Marketplace
 * @notice Deploy and manage sovereign agents
 */

'use client';

import React from 'react';
import { AgentSummoning } from '../components/AgentSummoning';

export default function AgentsPage(): React.ReactElement {
  return (
    <div className="min-h-screen bg-gray-950 text-purple-300 p-8">
      <h1 className="text-4xl font-bold text-purple-200 mb-2">🔮 Sovereign Agent Market</h1>
      <p className="text-purple-400 mb-8">Deploy ERC-8004 sovereign agents to guard your knowledge</p>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 max-w-6xl mx-auto">
        <AgentSummoning />

        <div className="space-y-6">
          <div className="p-6 bg-gray-900 rounded-lg border border-purple-700">
            <h2 className="text-xl font-bold text-purple-200 mb-4">📊 Swarm Statistics</h2>
            <div className="grid grid-cols-2 gap-3">
              {[
                { label: 'Active Agents', value: '3' },
                { label: 'Tasks Completed', value: '1,247' },
                { label: 'Total Bonded', value: '3.5 ETH' },
                { label: 'Threats Detected', value: '42' },
              ].map(stat => (
                <div key={stat.label} className="bg-gray-800 p-3 rounded text-center">
                  <p className="text-2xl font-bold text-purple-200">{stat.value}</p>
                  <p className="text-xs text-purple-400">{stat.label}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="p-6 bg-gray-900 rounded-lg border border-purple-700">
            <h2 className="text-xl font-bold text-purple-200 mb-4">📜 ERC-8004 Standard</h2>
            <p className="text-sm text-purple-400 mb-3">
              All Watcher agents conform to the ERC-8004 draft standard for
              on-chain agent identity and reputation management.
            </p>
            <ul className="text-sm space-y-2">
              {[
                '✓ On-chain identity registration',
                '✓ ETH bond for accountability',
                '✓ Capability attestation',
                '✓ Reputation scoring',
                '✓ A2A communication protocol',
              ].map(item => (
                <li key={item} className="text-purple-300">{item}</li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
