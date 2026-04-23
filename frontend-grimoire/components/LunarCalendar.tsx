/**
 * @title LunarCalendar — Moon-Phase Exploit Correlation Display
 * @notice React component for displaying lunar phases and associated blockchain risk
 */

'use client';

import React, { useState, useEffect } from 'react';

interface LunarData {
  phase: string;
  illumination: number;
  riskLevel: 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';
  riskScore: number;
  recommendation: string;
  daysUntilFull: number;
  daysUntilNew: number;
}

const PHASE_EMOJIS: Record<string, string> = {
  new_moon: '🌑',
  waxing_crescent: '🌒',
  first_quarter: '🌓',
  waxing_gibbous: '🌔',
  full_moon: '🌕',
  waning_gibbous: '🌖',
  last_quarter: '🌗',
  waning_crescent: '🌘',
};

const RISK_COLORS: Record<string, string> = {
  LOW: 'text-green-400',
  MODERATE: 'text-yellow-400',
  HIGH: 'text-orange-400',
  CRITICAL: 'text-red-400',
};

export function LunarCalendar(): React.ReactElement {
  const [lunarData, setLunarData] = useState<LunarData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simplified lunar computation (full computation in lunar-oracle.ts)
    const computeLunarData = (): LunarData => {
      const SYNODIC_MONTH = 29.530588853;
      const KNOWN_NEW_MOON = new Date('2000-01-06').getTime();
      const now = Date.now();
      const daysSinceNew = ((now - KNOWN_NEW_MOON) / 86400000) % SYNODIC_MONTH;
      const illumination = (1 - Math.cos((daysSinceNew / SYNODIC_MONTH) * 2 * Math.PI)) / 2;
      
      const phases = [
        'new_moon', 'waxing_crescent', 'first_quarter', 'waxing_gibbous',
        'full_moon', 'waning_gibbous', 'last_quarter', 'waning_crescent'
      ];
      const phaseIndex = Math.floor((daysSinceNew / SYNODIC_MONTH) * 8) % 8;
      const phase = phases[phaseIndex];
      
      const riskScore = phase === 'full_moon' || phase === 'new_moon' ? 65 : 30;
      const riskLevel = riskScore >= 60 ? 'HIGH' : riskScore >= 40 ? 'MODERATE' : 'LOW';
      
      return {
        phase,
        illumination,
        riskLevel,
        riskScore,
        recommendation: riskScore >= 60 
          ? 'CAUTION: Enhanced monitoring recommended' 
          : 'PROCEED: Normal operations advised',
        daysUntilFull: phase.includes('waxing') || phase === 'new_moon' 
          ? (SYNODIC_MONTH / 2) - daysSinceNew 
          : SYNODIC_MONTH - daysSinceNew + (SYNODIC_MONTH / 2),
        daysUntilNew: SYNODIC_MONTH - daysSinceNew,
      };
    };
    
    setLunarData(computeLunarData());
    setLoading(false);
  }, []);

  if (loading) return <div className="text-purple-400">Computing lunar phase...</div>;
  if (!lunarData) return <div className="text-red-400">Failed to compute lunar data</div>;

  return (
    <div className="lunar-calendar p-6 bg-gray-900 text-purple-300 rounded-lg border border-purple-700">
      <h2 className="text-2xl font-bold mb-6 text-purple-200">🌙 Lunar Oracle</h2>
      
      <div className="text-center mb-6">
        <span className="text-8xl">{PHASE_EMOJIS[lunarData.phase]}</span>
        <p className="text-xl mt-2 capitalize">{lunarData.phase.replace(/_/g, ' ')}</p>
        <p className="text-sm text-purple-400">
          {Math.round(lunarData.illumination * 100)}% illuminated
        </p>
      </div>
      
      <div className={`text-center mb-4 font-bold text-lg ${RISK_COLORS[lunarData.riskLevel]}`}>
        ⚠️ Risk Level: {lunarData.riskLevel} ({lunarData.riskScore}/100)
      </div>
      
      <p className="text-sm text-center text-purple-300 mb-4">{lunarData.recommendation}</p>
      
      <div className="grid grid-cols-2 gap-4 text-sm text-center">
        <div className="bg-gray-800 p-3 rounded">
          <p className="text-purple-400">Next Full Moon</p>
          <p className="text-purple-200 font-bold">{lunarData.daysUntilFull.toFixed(1)} days</p>
        </div>
        <div className="bg-gray-800 p-3 rounded">
          <p className="text-purple-400">Next New Moon</p>
          <p className="text-purple-200 font-bold">{lunarData.daysUntilNew.toFixed(1)} days</p>
        </div>
      </div>
    </div>
  );
}

export default LunarCalendar;
