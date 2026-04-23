/**
 * @title SigilGenerator — Visual Encoding Interface
 * @notice React component for generating and visualizing esoteric sigil hashes
 */

'use client';

import React, { useState, useCallback } from 'react';

type Planet = 'Saturn' | 'Jupiter' | 'Mars' | 'Sun' | 'Venus' | 'Mercury' | 'Moon';
type Element = 'Fire' | 'Water' | 'Air' | 'Earth';

interface SigilOutput {
  sigilHash: string;
  gematriaValue: number;
  description: string;
}

const PLANETS: Planet[] = ['Saturn', 'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon'];
const ELEMENTS: Element[] = ['Fire', 'Water', 'Air', 'Earth'];

const PLANET_SYMBOLS: Record<Planet, string> = {
  Saturn: '♄', Jupiter: '♃', Mars: '♂', Sun: '☉', Venus: '♀', Mercury: '☿', Moon: '☽'
};

const ELEMENT_SYMBOLS: Record<Element, string> = {
  Fire: '🔥', Water: '💧', Air: '💨', Earth: '🌍'
};

export function SigilGenerator(): React.ReactElement {
  const [symbolName, setSymbolName] = useState('');
  const [planet, setPlanet] = useState<Planet>('Mercury');
  const [element, setElement] = useState<Element>('Air');
  const [output, setOutput] = useState<SigilOutput | null>(null);
  const [loading, setLoading] = useState(false);

  const generateSigil = useCallback(async () => {
    if (!symbolName.trim()) return;
    
    setLoading(true);
    try {
      // In production: call sigil-generation MCP server
      const gematriaValue = symbolName.toLowerCase().split('').reduce((sum, c) => {
        const code = c.charCodeAt(0);
        return sum + (code >= 97 && code <= 122 ? code - 96 : 0);
      }, 0);
      
      setOutput({
        sigilHash: `0x${Math.abs(symbolName.length * gematriaValue).toString(16).padStart(64, '0')}`,
        gematriaValue,
        description: `${symbolName} sealed by ${PLANET_SYMBOLS[planet]} ${planet} under ${ELEMENT_SYMBOLS[element]} ${element}`,
      });
    } finally {
      setLoading(false);
    }
  }, [symbolName, planet, element]);

  return (
    <div className="sigil-generator p-6 bg-gray-900 text-purple-300 rounded-lg border border-purple-700">
      <h2 className="text-2xl font-bold mb-6 text-purple-200">⚗️ Sigil Generator</h2>
      
      <div className="mb-4">
        <label className="block text-sm mb-1">Symbol Name or Phrase</label>
        <input
          type="text"
          value={symbolName}
          onChange={e => setSymbolName(e.target.value)}
          placeholder="Enter symbol name (e.g., ETHEREUM, WATCHER)"
          className="w-full p-2 bg-gray-800 border border-purple-600 rounded text-purple-100"
        />
      </div>
      
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <label className="block text-sm mb-1">Ruling Planet</label>
          <select
            value={planet}
            onChange={e => setPlanet(e.target.value as Planet)}
            className="w-full p-2 bg-gray-800 border border-purple-600 rounded"
          >
            {PLANETS.map(p => (
              <option key={p} value={p}>{PLANET_SYMBOLS[p]} {p}</option>
            ))}
          </select>
        </div>
        
        <div>
          <label className="block text-sm mb-1">Element</label>
          <select
            value={element}
            onChange={e => setElement(e.target.value as Element)}
            className="w-full p-2 bg-gray-800 border border-purple-600 rounded"
          >
            {ELEMENTS.map(el => (
              <option key={el} value={el}>{ELEMENT_SYMBOLS[el]} {el}</option>
            ))}
          </select>
        </div>
      </div>
      
      <button
        onClick={generateSigil}
        disabled={loading || !symbolName.trim()}
        className="w-full py-2 bg-purple-700 hover:bg-purple-600 disabled:bg-gray-700 rounded font-bold"
      >
        {loading ? 'Casting...' : '✨ Generate Sigil'}
      </button>
      
      {output && (
        <div className="mt-6 p-4 bg-gray-800 rounded border border-purple-500">
          <p className="text-sm text-purple-400 mb-2">Sigil Hash:</p>
          <p className="font-mono text-xs text-purple-200 break-all">{output.sigilHash}</p>
          <p className="text-sm text-purple-400 mt-3">Gematria Value: <span className="text-purple-200">{output.gematriaValue}</span></p>
          <p className="text-sm text-purple-400 mt-1">Description: <span className="text-purple-200">{output.description}</span></p>
        </div>
      )}
    </div>
  );
}

export default SigilGenerator;
