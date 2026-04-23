/**
 * @title Main Grimoire Portal
 * @notice Home page for the Watcher Tech Blockchain Grimoire
 */

'use client';

import React from 'react';
import { LunarCalendar } from '../components/LunarCalendar';
import { KnowledgeViewer } from '../components/KnowledgeViewer';

export default function GrimoirePortal(): React.ReactElement {
  return (
    <main className="min-h-screen bg-gray-950 text-purple-300 p-8">
      <header className="text-center mb-12">
        <h1 className="text-5xl font-bold text-purple-200 mb-4">
          👁️ Watcher Tech Blockchain Grimoire
        </h1>
        <p className="text-xl text-purple-400 max-w-2xl mx-auto">
          Ancient wisdom meets blockchain technology. The esoteric origins of
          distributed systems, consensus algorithms, and cryptographic truth.
        </p>
        <div className="flex gap-4 justify-center mt-6">
          <a href="/library" className="px-6 py-2 bg-purple-700 hover:bg-purple-600 rounded-lg font-bold">
            📚 Enter Library
          </a>
          <a href="/agents" className="px-6 py-2 border border-purple-600 hover:bg-purple-900/30 rounded-lg">
            🔮 Summon Agent
          </a>
          <a href="/rituals" className="px-6 py-2 border border-purple-600 hover:bg-purple-900/30 rounded-lg">
            ⚗️ Rituals
          </a>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-6xl mx-auto">
        <LunarCalendar />
        <div>
          <div className="p-6 bg-gray-900 rounded-lg border border-purple-700 mb-6">
            <h2 className="text-xl font-bold text-purple-200 mb-3">🌳 Grimoire Overview</h2>
            <div className="grid grid-cols-2 gap-3 text-center">
              {[
                { label: 'Esoteric Domains', value: '5' },
                { label: 'Knowledge Entries', value: '15+' },
                { label: 'Smart Contracts', value: '5' },
                { label: 'Sovereign Agents', value: '3' },
              ].map(stat => (
                <div key={stat.label} className="bg-gray-800 p-3 rounded">
                  <p className="text-2xl font-bold text-purple-200">{stat.value}</p>
                  <p className="text-xs text-purple-400">{stat.label}</p>
                </div>
              ))}
            </div>
          </div>
          <KnowledgeViewer />
        </div>
      </div>

      <section className="mt-12 max-w-4xl mx-auto">
        <h2 className="text-3xl font-bold text-center text-purple-200 mb-8">
          The Five Esoteric Pillars
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
          {[
            { icon: '👼', title: 'Primordial', desc: 'Watchers & Grigori' },
            { icon: '🗿', title: 'Nephilim', desc: 'Sacred Geometry' },
            { icon: '🏛️', title: 'Canaanite', desc: 'Seven Sages' },
            { icon: '📜', title: 'Mystery Schools', desc: 'Hermetic Arts' },
            { icon: '🏦', title: 'Bloodlines', desc: 'Banking Origins' },
          ].map(pillar => (
            <div key={pillar.title} className="text-center p-4 bg-gray-900 rounded-lg border border-purple-800">
              <span className="text-3xl">{pillar.icon}</span>
              <p className="font-bold text-purple-200 mt-2">{pillar.title}</p>
              <p className="text-xs text-purple-400">{pillar.desc}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
