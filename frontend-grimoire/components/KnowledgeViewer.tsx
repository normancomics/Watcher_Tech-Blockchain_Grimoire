/**
 * @title KnowledgeViewer — NFT-Gated Content Reader
 * @notice React component for viewing access-controlled esoteric knowledge
 */

'use client';

import React, { useState } from 'react';

interface KnowledgeEntry {
  id: string;
  title: string;
  domain: string;
  accessLevel: 'PUBLIC' | 'INITIATED' | 'ADEPT' | 'MASTER';
  preview: string;
  content?: string;
  verified: boolean;
  upvotes: number;
}

const MOCK_ENTRIES: KnowledgeEntry[] = [
  {
    id: '1',
    title: 'Fallen Angel Technology Transfer',
    domain: 'Primordial Traditions',
    accessLevel: 'PUBLIC',
    verified: true,
    upvotes: 42,
    preview: 'The Watchers (Grigori) of 1 Enoch 6-8 transferred 18 specific technologies...',
    content: 'Full content available to public readers...',
  },
  {
    id: '2',
    title: 'Kabbalistic Merkle Trees',
    domain: 'Mystery Schools',
    accessLevel: 'INITIATED',
    verified: true,
    upvotes: 87,
    preview: 'The Tree of Life (Etz HaChayyim) provides the data structure blueprint...',
    content: 'Full content requires Initiate token...',
  },
  {
    id: '3',
    title: 'Enochian Consensus Algorithm',
    domain: 'Technical Grimoire',
    accessLevel: 'ADEPT',
    verified: false,
    upvotes: 23,
    preview: 'The 30 Aethyrs of John Dee\'s system map to validation epochs...',
    content: 'Full content requires Adept reputation...',
  },
];

const ACCESS_BADGES: Record<string, { icon: string; color: string }> = {
  PUBLIC: { icon: '🌐', color: 'text-green-400' },
  INITIATED: { icon: '🔑', color: 'text-blue-400' },
  ADEPT: { icon: '⭐', color: 'text-yellow-400' },
  MASTER: { icon: '👑', color: 'text-purple-400' },
};

export function KnowledgeViewer(): React.ReactElement {
  const [selectedEntry, setSelectedEntry] = useState<KnowledgeEntry | null>(null);
  const [userLevel] = useState<string>('INITIATED');  // Simulated

  const canAccess = (accessLevel: string): boolean => {
    const levels = ['PUBLIC', 'INITIATED', 'ADEPT', 'MASTER'];
    return levels.indexOf(userLevel) >= levels.indexOf(accessLevel);
  };

  return (
    <div className="knowledge-viewer p-6 bg-gray-900 text-purple-300 rounded-lg border border-purple-700">
      <h2 className="text-2xl font-bold mb-2 text-purple-200">📚 Grimoire Library</h2>
      <p className="text-sm text-purple-400 mb-6">Your access level: <span className="text-purple-200">{userLevel}</span></p>
      
      <div className="grid gap-3 mb-4">
        {MOCK_ENTRIES.map(entry => {
          const badge = ACCESS_BADGES[entry.accessLevel];
          const accessible = canAccess(entry.accessLevel);
          
          return (
            <div
              key={entry.id}
              onClick={() => accessible && setSelectedEntry(entry)}
              className={`p-4 rounded-lg border transition-colors ${
                accessible 
                  ? 'border-purple-700 hover:border-purple-500 cursor-pointer' 
                  : 'border-gray-700 opacity-50 cursor-not-allowed'
              }`}
            >
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className={badge.color}>{badge.icon}</span>
                    <span className="font-bold text-purple-200">{entry.title}</span>
                    {entry.verified && <span className="text-xs text-green-400">✓ Verified</span>}
                  </div>
                  <p className="text-xs text-purple-400 mb-1">{entry.domain}</p>
                  <p className="text-sm">{entry.preview}</p>
                </div>
                <div className="text-xs text-purple-500 ml-4">
                  ▲ {entry.upvotes}
                </div>
              </div>
            </div>
          );
        })}
      </div>
      
      {selectedEntry && (
        <div className="mt-4 p-4 bg-gray-800 rounded border border-purple-500">
          <div className="flex justify-between items-center mb-3">
            <h3 className="font-bold text-purple-200">{selectedEntry.title}</h3>
            <button onClick={() => setSelectedEntry(null)} className="text-purple-400 hover:text-purple-200">✕</button>
          </div>
          <p className="text-sm">{selectedEntry.content}</p>
        </div>
      )}
    </div>
  );
}

export default KnowledgeViewer;
