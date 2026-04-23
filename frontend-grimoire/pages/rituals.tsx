/**
 * @title Rituals — Interactive Ceremonies
 * @notice Page for executing on-chain rituals and ceremonies
 */

'use client';

import React, { useState } from 'react';
import { SigilGenerator } from '../components/SigilGenerator';
import { LunarCalendar } from '../components/LunarCalendar';

type Ritual = 'key-ceremony' | 'sigil-casting' | 'contract-blessing' | 'agent-attunement';

const RITUALS: { id: Ritual; name: string; icon: string; description: string; minParticipants: number }[] = [
  {
    id: 'key-ceremony',
    name: 'Key Generation Ceremony',
    icon: '🗝️',
    description: 'Multi-party trusted setup for cryptographic key generation. Requires 7 participants (Seven Pillars).',
    minParticipants: 7,
  },
  {
    id: 'sigil-casting',
    name: 'Sigil Casting',
    icon: '⚗️',
    description: 'Generate a deterministic sigil hash from symbolic inputs for on-chain commitments.',
    minParticipants: 1,
  },
  {
    id: 'contract-blessing',
    name: 'Contract Blessing',
    icon: '📜',
    description: 'Ritual blessing of a smart contract address using planetary and elemental correspondences.',
    minParticipants: 3,
  },
  {
    id: 'agent-attunement',
    name: 'Agent Attunement',
    icon: '🔮',
    description: 'Formally attune an AI agent to the Grimoire through signature verification.',
    minParticipants: 1,
  },
];

export default function RitualsPage(): React.ReactElement {
  const [selectedRitual, setSelectedRitual] = useState<Ritual | null>(null);

  return (
    <div className="min-h-screen bg-gray-950 text-purple-300 p-8">
      <h1 className="text-4xl font-bold text-purple-200 mb-2">⚗️ Ritual Chamber</h1>
      <p className="text-purple-400 mb-8">Execute on-chain ceremonies with celestial timing</p>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 max-w-7xl mx-auto">
        <div className="lg:col-span-2 space-y-4">
          <h2 className="text-xl font-bold text-purple-200">Available Rituals</h2>
          {RITUALS.map(ritual => (
            <button
              key={ritual.id}
              onClick={() => setSelectedRitual(ritual.id)}
              className={`w-full p-4 rounded-lg border text-left transition-colors ${
                selectedRitual === ritual.id
                  ? 'border-purple-400 bg-purple-900/30'
                  : 'border-purple-800 hover:border-purple-600'
              }`}
            >
              <div className="flex items-start gap-4">
                <span className="text-4xl">{ritual.icon}</span>
                <div>
                  <p className="font-bold text-purple-200">{ritual.name}</p>
                  <p className="text-sm text-purple-400 mt-1">{ritual.description}</p>
                  <p className="text-xs text-purple-500 mt-2">
                    Min participants: {ritual.minParticipants}
                  </p>
                </div>
              </div>
            </button>
          ))}

          {selectedRitual === 'sigil-casting' && (
            <div className="mt-4">
              <SigilGenerator />
            </div>
          )}
        </div>

        <div className="space-y-6">
          <LunarCalendar />
          <div className="p-4 bg-gray-900 rounded-lg border border-purple-700">
            <h3 className="font-bold text-purple-200 mb-2">⏰ Celestial Timing</h3>
            <p className="text-sm text-purple-400">
              For optimal results, perform rituals during favorable lunar windows.
              The Lunar Oracle monitors timing conditions in real-time.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
