'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useRouter } from 'next/navigation';

export default function CricketLiveScorecard({ params }: { params: { fixture_id: string } }) {
  const router = useRouter();
  const [match, setMatch] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadScore() {
      try {
        const data = await api.getCricketLiveScore(params.fixture_id);
        setMatch(data);
      } catch (err: any) {
        setError(err.message || 'Failed to load match or match not initialized.');
      } finally {
        setLoading(false);
      }
    }
    loadScore();
    const interval = setInterval(loadScore, 5000);
    return () => clearInterval(interval);
  }, [params.fixture_id]);

  if (loading) {
    return <div className="flex justify-center items-center h-screen"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div></div>;
  }

  if (error || !match) {
    return (
      <div className="flex flex-col items-center justify-center h-[70vh]">
        <div className="bg-red-50 text-red-600 p-6 rounded-xl max-w-md text-center shadow-lg border border-red-100">
          <span className="text-4xl mb-4 block">🏏</span>
          <h2 className="text-xl font-bold mb-2">Match Not Available</h2>
          <p className="text-sm">{error || 'Live score not started yet.'}</p>
          <button onClick={() => router.back()} className="mt-6 bg-red-600 text-white px-6 py-2 rounded-lg text-sm font-medium hover:bg-red-700 transition-colors">Go Back</button>
        </div>
      </div>
    );
  }

  const s = match.match_state || {};
  const {
    innings = 1,
    score = 0,
    wickets = 0,
    overs = 0,
    balls = 0,
    target = null,
    batters = {},
    bowlers = {},
    extras = { w: 0, nb: 0, b: 0, lb: 0 }
  } = s;

  // Derive active batters & bowlers
  const activeBatters = Object.values(batters).filter((b: any) => !b.out);
  const allBowlers = Object.values(bowlers);
  
  const totalOvers = match.overs_per_innings || 20;
  
  const runRate = ((overs * 6 + balls) > 0) ? ((score / (overs * 6 + balls)) * 6).toFixed(2) : '0.00';
  const reqRunRate = target && innings === 2 
    ? ((((target - score) / ((totalOvers * 6) - (overs * 6 + balls))) * 6).toFixed(2)) 
    : null;

  return (
    <div className="min-h-screen bg-gray-50 p-4 md:p-8 font-sans">
      <div className="max-w-3xl mx-auto">
        <button onClick={() => router.back()} className="mb-6 text-sm text-gray-500 hover:text-gray-900 flex items-center transition-colors">
          ← Back to Dashboard
        </button>

        {/* Main Scorecard Card */}
        <div className="bg-gradient-to-br from-gray-900 to-black rounded-3xl shadow-2xl overflow-hidden text-white relative">
          
          {/* Subtle background pattern/glow */}
          <div className="absolute top-0 right-0 -mr-16 -mt-16 w-64 h-64 bg-primary/20 rounded-full blur-3xl opacity-50 pointer-events-none"></div>
          
          <div className="p-6 md:p-8 relative z-10">
            {/* Header / Context */}
            <div className="flex justify-between items-center mb-8 border-b border-white/10 pb-4">
              <div className="flex items-center gap-3">
                <span className="text-3xl animate-bounce">🏏</span>
                <div>
                  <h1 className="text-xl font-bold tracking-wide">LIVE CRICKET</h1>
                  <p className="text-xs text-gray-400 uppercase tracking-wider">{match.status.replace('_', ' ')} • {totalOvers} OVERS</p>
                </div>
              </div>
              <div className="text-right">
                <span className="inline-block px-3 py-1 bg-red-500/20 text-red-400 border border-red-500/30 rounded-full text-xs font-bold tracking-widest animate-pulse">
                  LIVE
                </span>
              </div>
            </div>

            {/* Score Display */}
            <div className="flex flex-col md:flex-row justify-between items-center mb-8 gap-6">
              <div className="text-center md:text-left">
                <div className="text-xs text-gray-400 uppercase tracking-wider mb-1">Innings {innings}</div>
                <div className="flex items-baseline justify-center md:justify-start gap-2">
                  <span className="text-7xl md:text-8xl font-black tracking-tighter bg-clip-text text-transparent bg-gradient-to-b from-white to-gray-400">
                    {score}<span className="text-4xl md:text-5xl text-gray-500">/{wickets}</span>
                  </span>
                </div>
                <div className="text-lg text-gray-400 font-medium mt-2">
                  Overs: <span className="text-white font-bold">{overs}.{balls}</span>
                  <span className="mx-2 text-gray-600">|</span>
                  CRR: <span className="text-white">{runRate}</span>
                </div>
              </div>

              {/* Target / Equation */}
              {innings === 2 && target && (
                <div className="bg-white/5 border border-white/10 rounded-2xl p-5 text-center backdrop-blur-sm min-w-[200px]">
                  <div className="text-xs text-gray-400 uppercase tracking-wider mb-1">Target</div>
                  <div className="text-3xl font-bold text-primary mb-2">{target}</div>
                  {score < target ? (
                    <div className="text-sm font-medium text-gray-300">
                      Need <span className="text-white font-bold">{target - score}</span> runs
                      <br/>in <span className="text-white font-bold">{(totalOvers * 6) - (overs * 6 + balls)}</span> balls
                      <br/><span className="text-xs text-gray-500 mt-1 block">RRR: {reqRunRate}</span>
                    </div>
                  ) : (
                    <div className="text-sm font-medium text-green-400">Target Reached</div>
                  )}
                </div>
              )}
            </div>

            {/* Match Status / Toss info */}
            <div className="text-center bg-white/5 py-3 rounded-xl mb-8 text-sm text-gray-300 border border-white/5">
              {match.status === 'INNINGS_BREAK' ? 'Innings Break' : `Toss winner decided to ${match.toss_decision.toLowerCase()} first`}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {/* Batting Section */}
              <div>
                <h3 className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-4 border-b border-white/10 pb-2">Batters</h3>
                <div className="space-y-3">
                  {activeBatters.length > 0 ? activeBatters.map((b: any, idx: number) => (
                    <div key={idx} className="flex justify-between items-center bg-white/5 rounded-lg p-3 border border-white/5 hover:bg-white/10 transition-colors">
                      <div className="font-medium flex items-center gap-2 text-sm md:text-base">
                        {b.name} 
                        {idx === 0 && <span className="w-2 h-2 rounded-full bg-primary inline-block shadow-[0_0_8px_rgba(59,130,246,0.8)]"></span>}
                      </div>
                      <div className="text-right">
                        <span className="font-bold text-lg">{b.runs}</span>
                        <span className="text-xs text-gray-400 ml-1">({b.balls})</span>
                        <div className="text-[10px] text-gray-500 mt-0.5">
                          {b.fours}x4 • {b.sixes}x6 • SR: {b.balls > 0 ? ((b.runs / b.balls) * 100).toFixed(1) : '0.0'}
                        </div>
                      </div>
                    </div>
                  )) : (
                    <div className="text-sm text-gray-500 italic">No active batters</div>
                  )}
                </div>
              </div>

              {/* Bowling Section */}
              <div>
                <h3 className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-4 border-b border-white/10 pb-2">Bowlers</h3>
                <div className="space-y-3">
                  {allBowlers.map((b: any, idx: number) => {
                    const bOvers = Math.floor(b.legal_balls / 6);
                    const bBalls = b.legal_balls % 6;
                    const bEcon = b.legal_balls > 0 ? ((b.runs / (b.legal_balls / 6))).toFixed(1) : '0.0';
                    return (
                      <div key={idx} className="flex justify-between items-center bg-white/5 rounded-lg p-3 border border-white/5 hover:bg-white/10 transition-colors">
                        <div className="font-medium text-sm md:text-base text-gray-300">{b.name}</div>
                        <div className="flex gap-4 text-center">
                          <div>
                            <div className="text-[10px] text-gray-500 uppercase">O</div>
                            <div className="font-medium text-sm">{bOvers}.{bBalls}</div>
                          </div>
                          <div>
                            <div className="text-[10px] text-gray-500 uppercase">M</div>
                            <div className="font-medium text-sm">0</div>
                          </div>
                          <div>
                            <div className="text-[10px] text-gray-500 uppercase">R</div>
                            <div className="font-medium text-sm">{b.runs}</div>
                          </div>
                          <div>
                            <div className="text-[10px] text-gray-500 uppercase">W</div>
                            <div className="font-bold text-white text-sm">{b.wickets}</div>
                          </div>
                          <div>
                            <div className="text-[10px] text-gray-500 uppercase">ECO</div>
                            <div className="font-medium text-sm text-gray-400">{bEcon}</div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                  {allBowlers.length === 0 && (
                    <div className="text-sm text-gray-500 italic">No bowling data</div>
                  )}
                </div>

                {/* Extras */}
                <div className="mt-6 pt-4 border-t border-white/10 flex justify-between items-center text-sm">
                  <span className="text-gray-400">Extras</span>
                  <div className="flex gap-3 text-gray-300">
                    <span>W: <span className="text-white">{extras.w}</span></span>
                    <span>NB: <span className="text-white">{extras.nb}</span></span>
                    <span>B: <span className="text-white">{extras.b}</span></span>
                    <span>LB: <span className="text-white">{extras.lb}</span></span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
