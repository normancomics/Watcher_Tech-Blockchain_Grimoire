/**
 * @title Library — Esoteric Text Browser
 * @notice Full library page for browsing all grimoire entries
 */

'use client';

import React, { useState } from 'react';
import { KnowledgeViewer } from '../components/KnowledgeViewer';

type DomainFilter = 'all' | 'primordial' | 'nephilim' | 'canaanite' | 'mystery' | 'bloodlines' | 'technical';

export default function LibraryPage(): React.ReactElement {
  const [domainFilter, setDomainFilter] = useState<DomainFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const DOMAIN_FILTERS: { value: DomainFilter; label: string; icon: string }[] = [
    { value: 'all', label: 'All', icon: '📚' },
    { value: 'primordial', label: 'Primordial', icon: '👼' },
    { value: 'nephilim', label: 'Nephilim', icon: '🗿' },
    { value: 'canaanite', label: 'Canaanite', icon: '🏛️' },
    { value: 'mystery', label: 'Mystery Schools', icon: '📜' },
    { value: 'bloodlines', label: '13 Bloodlines', icon: '🏦' },
    { value: 'technical', label: 'Technical', icon: '⚙️' },
  ];

  return (
    <div className="min-h-screen bg-gray-950 text-purple-300 p-8">
      <h1 className="text-4xl font-bold text-purple-200 mb-2">📚 Grimoire Library</h1>
      <p className="text-purple-400 mb-8">Browse the complete esoteric knowledge corpus</p>

      <div className="mb-6">
        <input
          type="text"
          value={searchQuery}
          onChange={e => setSearchQuery(e.target.value)}
          placeholder="Search esoteric knowledge..."
          className="w-full max-w-lg p-3 bg-gray-900 border border-purple-600 rounded-lg"
        />
      </div>

      <div className="flex gap-2 flex-wrap mb-8">
        {DOMAIN_FILTERS.map(filter => (
          <button
            key={filter.value}
            onClick={() => setDomainFilter(filter.value)}
            className={`px-3 py-1.5 rounded-full text-sm transition-colors ${
              domainFilter === filter.value
                ? 'bg-purple-700 text-white'
                : 'border border-purple-700 hover:bg-purple-900/30'
            }`}
          >
            {filter.icon} {filter.label}
          </button>
        ))}
      </div>

      <KnowledgeViewer />
    </div>
  );
}
