'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';

export default function CricketScorer({ params }: { params: { id: string } }) {
  const router = useRouter();
  const [match, setMatch] = useState<any>(null);
  const [currentPlayers, setCurrentPlayers] = useState<any>(null);
  
  // Init form
  const [initForm, setInitForm] = useState({
    toss_winner_id: '',
    toss_decision: 'BAT',
    overs: 20,
    striker_name: '',
    non_striker_name: '',
    bowler_name: ''
  });

  const [loading, setLoading] = useState(true);
  const [teams, setTeams] = useState<any[]>([]);
  const [fixture, setFixture] = useState<any>(null);

  useEffect(() => {
    loadData();
  }, [params.id]);

  async function loadData() {
    try {
      // Get the match state if it exists
      const m = await fetch(`/api/v1/fixtures/${params.id}/cricket`, {
        headers: { 'Authorization': `Bearer ${localStorage.getItem('fyc_token')}` }
      }).then(r => r.ok ? r.json() : null);
      
      setMatch(m);

      if (m && m.match_state) {
        // Find current players from state
        // For simplicity, we just need striker_id, non_striker_id, bowler_id.
        // We will maintain them in local state for the UI, swapping them on runs.
        // But for initialization, we'll fetch them from the latest ball or state?
        // Actually, let's just let the UI handle the state when we score.
      } else {
        // Fetch fixture and teams to populate the init form
        // Wait, we need to know the teams involved. We can fetch them via a generic API or just let the user type?
        // The API requires toss_winner_id, which requires the team ID.
        // This is an admin panel, let's just fetch the fixture details.
      }
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  }

  if (loading) return <div className="p-8 text-center">Loading...</div>;

  if (!match) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white rounded-xl shadow-sm mt-10">
        <h2 className="text-xl font-bold mb-4">Initialize Cricket Match</h2>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-600 mb-1">Toss Winner Team ID (UUID)</label>
            <input className="w-full border p-2 rounded" value={initForm.toss_winner_id} onChange={e => setInitForm({...initForm, toss_winner_id: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm text-gray-600 mb-1">Decision</label>
            <select className="w-full border p-2 rounded" value={initForm.toss_decision} onChange={e => setInitForm({...initForm, toss_decision: e.target.value})}>
              <option value="BAT">Bat</option>
              <option value="BOWL">Bowl</option>
            </select>
          </div>
          <div>
            <label className="block text-sm text-gray-600 mb-1">Overs</label>
            <input type="number" className="w-full border p-2 rounded" value={initForm.overs} onChange={e => setInitForm({...initForm, overs: +e.target.value})} />
          </div>
          <div>
            <label className="block text-sm text-gray-600 mb-1">Striker Name</label>
            <input className="w-full border p-2 rounded" value={initForm.striker_name} onChange={e => setInitForm({...initForm, striker_name: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm text-gray-600 mb-1">Non-Striker Name</label>
            <input className="w-full border p-2 rounded" value={initForm.non_striker_name} onChange={e => setInitForm({...initForm, non_striker_name: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm text-gray-600 mb-1">Bowler Name</label>
            <input className="w-full border p-2 rounded" value={initForm.bowler_name} onChange={e => setInitForm({...initForm, bowler_name: e.target.value})} />
          </div>
          
          <button 
            className="w-full bg-indigo-600 text-white font-bold py-2 rounded mt-4"
            onClick={async () => {
              const res = await fetch(`/api/v1/fixtures/${params.id}/cricket/init`, {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': `Bearer ${localStorage.getItem('fyc_token')}`
                },
                body: JSON.stringify(initForm)
              }).then(r => r.json());
              if (res.match) {
                setMatch(res.match);
                setCurrentPlayers(res.current_players);
                window.location.reload();
              }
            }}
          >
            Start Match
          </button>
        </div>
      </div>
    );
  }

  return (
    <CricketScoreboard match={match} fixtureId={params.id} />
  );
}

function CricketScoreboard({ match: initialMatch, fixtureId }: { match: any, fixtureId: string }) {
  const [match, setMatch] = useState(initialMatch);
  const state = match.match_state;
  
  // We need to track the active players in the UI so the scorer doesn't have to input them
  // We can figure out the current striker/non-striker/bowler from the state if we want,
  // but it's easier to just keep a local React state for the "active" players that gets passed with every ball.
  
  // We will just fetch the latest ball to know the exact active players, or we can look at the batters dictionary
  // and pick two who are not "out".
  const activeBatters = Object.keys(state.batters).filter(k => !state.batters[k].out);
  
  const [strikerId, setStrikerId] = useState(activeBatters[0] || '');
  const [nonStrikerId, setNonStrikerId] = useState(activeBatters[1] || '');
  // For bowler, we'd theoretically need to know who bowled last. If it's a new over, the UI asks.
  const [bowlerId, setBowlerId] = useState(Object.keys(state.bowlers).pop() || '');

  const [scoringAction, setScoringAction] = useState<any>(null); // For wickets, extras, etc.
  
  const token = typeof window !== 'undefined' ? localStorage.getItem('fyc_token') : '';

  async function postBall(payload: any) {
    let finalPayload = { ...payload };
    if (scoringAction?.type === 'PENDING_NEW_BOWLER') {
      finalPayload.new_bowler_name = scoringAction.name;
    }
    
    const res = await fetch(`/api/v1/fixtures/${fixtureId}/cricket/ball`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        striker_id: strikerId,
        non_striker_id: nonStrikerId,
        bowler_id: bowlerId,
        ...finalPayload
      })
    });
    if (!res.ok) {
      alert("Error scoring ball");
      return;
    }
    const data = await res.json();
    setMatch({ ...match, match_state: data.match_state });
    
    if (scoringAction?.type === 'PENDING_NEW_BOWLER') {
        // Need to reload to get new bowler ID, or we can just fetch it from data
        window.location.reload();
        return;
    }

    // Auto-swap strike on 1, 3 runs
    const runs = payload.runs_batter || 0;
    if (runs === 1 || runs === 3) {
      swapStrike();
    }
    
    // Auto-swap on over end is tricky if we don't know if the ball completed an over.
    // The match_state has state.balls. If data.match_state.balls === 0, over is done!
    if (data.match_state.balls === 0 && data.match_state.overs > 0 && !payload.is_wicket) {
      swapStrike();
      setScoringAction({ type: 'NEW_BOWLER' }); // Prompt for next bowler
    }
  }

  function swapStrike() {
    setStrikerId(nonStrikerId);
    setNonStrikerId(strikerId);
  }

  async function undoBall() {
    if (!confirm("Undo last ball?")) return;
    const res = await fetch(`/api/v1/fixtures/${fixtureId}/cricket/undo`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (res.ok) {
      const data = await res.json();
      setMatch({ ...match, match_state: data.match_state });
    }
  }

  if (match.status === 'INNINGS_BREAK') {
    return (
      <div className="p-8 text-center">
        <h2 className="text-2xl font-bold mb-4">Innings Break!</h2>
        <p className="mb-4">Target: {state.score + 1}</p>
        <button className="px-4 py-2 bg-indigo-600 text-white rounded" onClick={() => setScoringAction({ type: 'SECOND_INNINGS' })}>Start Second Innings</button>
        {scoringAction?.type === 'SECOND_INNINGS' && (
          <div className="mt-4 p-4 border rounded max-w-sm mx-auto space-y-2 bg-white">
             <input id="s2" placeholder="Striker Name" className="border p-2 w-full rounded" />
             <input id="ns2" placeholder="Non-Striker Name" className="border p-2 w-full rounded" />
             <input id="b2" placeholder="Bowler Name" className="border p-2 w-full rounded" />
             <button className="w-full bg-green-600 text-white p-2 rounded font-bold" onClick={async () => {
               const res = await fetch(`/api/v1/fixtures/${fixtureId}/cricket/second-innings`, {
                 method: 'POST',
                 headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                 body: JSON.stringify({
                   toss_winner_id: '', toss_decision: '', overs: 0,
                   striker_name: (document.getElementById('s2') as HTMLInputElement).value,
                   non_striker_name: (document.getElementById('ns2') as HTMLInputElement).value,
                   bowler_name: (document.getElementById('b2') as HTMLInputElement).value,
                 })
               }).then(r => r.json());
               setMatch({ ...match, match_state: res.match_state, status: 'SECOND_INNINGS' });
               setStrikerId(res.current_players.striker_id);
               setNonStrikerId(res.current_players.non_striker_id);
               setBowlerId(res.current_players.bowler_id);
               setScoringAction(null);
             }}>Start</button>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto bg-gray-100 min-h-screen pb-10">
      {/* Scoreboard Header */}
      <div className="bg-indigo-900 text-white p-6 shadow-md relative">
        <button onClick={undoBall} className="absolute top-4 right-4 bg-red-500 hover:bg-red-600 px-3 py-1 rounded text-xs font-bold shadow">↶ UNDO</button>
        <div className="text-center">
          <div className="text-5xl font-black mb-1">{state.score}-{state.wickets}</div>
          <div className="text-lg opacity-90">Overs: {state.overs}.{state.balls} / {match.overs_per_innings}</div>
          {state.target && <div className="mt-2 text-yellow-300 font-bold">Target: {state.target}</div>}
        </div>
      </div>

      {/* Players */}
      <div className="bg-white p-4 shadow-sm mb-2 text-sm border-b">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <div className="text-gray-500 mb-1 font-semibold uppercase text-xs tracking-wide">Batters</div>
            <div className={`font-bold ${strikerId === activeBatters[0] ? 'text-indigo-600' : ''}`}>
              {state.batters[strikerId]?.name || 'Striker'} * ({state.batters[strikerId]?.runs || 0})
            </div>
            <div className={`font-bold ${nonStrikerId === activeBatters[1] ? 'text-indigo-600' : ''}`}>
              {state.batters[nonStrikerId]?.name || 'Non-Striker'} ({state.batters[nonStrikerId]?.runs || 0})
            </div>
          </div>
          <div>
            <div className="text-gray-500 mb-1 font-semibold uppercase text-xs tracking-wide">Bowler</div>
            <div className="font-bold text-gray-800">
              {state.bowlers[bowlerId]?.name || 'Bowler'}
            </div>
            <div className="text-gray-600">
              {Math.floor((state.bowlers[bowlerId]?.legal_balls || 0)/6)}.{ (state.bowlers[bowlerId]?.legal_balls || 0)%6 } - {state.bowlers[bowlerId]?.runs || 0} - {state.bowlers[bowlerId]?.wickets || 0}
            </div>
          </div>
        </div>
      </div>

      {/* Controls */}
      <div className="p-4 grid grid-cols-3 gap-3">
        <button className="bg-white border-2 border-gray-200 text-gray-800 text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 0 })}>0</button>
        <button className="bg-white border-2 border-gray-200 text-gray-800 text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 1 })}>1</button>
        <button className="bg-white border-2 border-gray-200 text-gray-800 text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 2 })}>2</button>
        <button className="bg-white border-2 border-gray-200 text-gray-800 text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 3 })}>3</button>
        <button className="bg-indigo-100 border-2 border-indigo-300 text-indigo-700 text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 4 })}>4</button>
        <button className="bg-indigo-600 border-2 border-indigo-700 text-white text-xl font-bold p-4 rounded-xl shadow-sm active:scale-95 transition-transform" onClick={() => postBall({ runs_batter: 6 })}>6</button>
        
        <button className="col-span-1 bg-yellow-100 text-yellow-800 font-bold p-3 rounded-xl shadow-sm" onClick={() => setScoringAction({ type: 'WIDE' })}>WIDE</button>
        <button className="col-span-1 bg-yellow-100 text-yellow-800 font-bold p-3 rounded-xl shadow-sm" onClick={() => setScoringAction({ type: 'NO_BALL' })}>NB</button>
        <button className="col-span-1 bg-red-100 text-red-700 font-bold p-3 rounded-xl shadow-sm" onClick={() => setScoringAction({ type: 'WICKET' })}>WICKET</button>
      </div>

      {/* Modals */}
      {scoringAction?.type === 'WICKET' && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white p-6 rounded-xl w-full max-w-sm">
            <h3 className="font-bold text-lg mb-4 text-red-600">Wicket!</h3>
            <select id="w_type" className="w-full border p-2 rounded mb-3">
              <option value="BOWLED">Bowled</option>
              <option value="CAUGHT">Caught</option>
              <option value="RUN_OUT">Run Out</option>
              <option value="LBW">LBW</option>
              <option value="STUMPED">Stumped</option>
            </select>
            <select id="w_who" className="w-full border p-2 rounded mb-3">
              <option value={strikerId}>{state.batters[strikerId]?.name}</option>
              <option value={nonStrikerId}>{state.batters[nonStrikerId]?.name}</option>
            </select>
            <input id="w_new" placeholder="New Batter Name" className="w-full border p-2 rounded mb-4" />
            <div className="flex gap-2">
              <button className="flex-1 bg-gray-200 p-2 rounded" onClick={() => setScoringAction(null)}>Cancel</button>
              <button className="flex-1 bg-red-600 text-white p-2 rounded font-bold" onClick={async () => {
                const wWho = (document.getElementById('w_who') as HTMLSelectElement).value;
                const newB = (document.getElementById('w_new') as HTMLInputElement).value;
                await postBall({
                  is_wicket: true,
                  wicket_type: (document.getElementById('w_type') as HTMLSelectElement).value,
                  player_dismissed_id: wWho,
                  new_batter_name: newB,
                  runs_batter: 0
                });
                
                // After server creates new player, we need to know their ID to set as striker/non-striker.
                // The server response `new_state` will have the new batter in `state.batters`.
                // For simplicity, we just reload the page to pick up the new IDs correctly, 
                // OR we fetch the latest ball. Let's just reload to be completely safe in this MVP.
                window.location.reload();
              }}>Out!</button>
            </div>
          </div>
        </div>
      )}

      {scoringAction?.type === 'NEW_BOWLER' && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white p-6 rounded-xl w-full max-w-sm">
            <h3 className="font-bold text-lg mb-4 text-indigo-600">Over Complete!</h3>
            <input id="nb_new" placeholder="Next Bowler Name" className="w-full border p-2 rounded mb-4" />
            <button className="w-full bg-indigo-600 text-white p-2 rounded font-bold" onClick={async () => {
              const newB = (document.getElementById('nb_new') as HTMLInputElement).value;
              // We don't post a ball, we just update the local state bowlerId.
              // Wait, we need the player ID. We can make a dummy request or just let the next ball create it!
              // The next ball endpoint accepts `new_bowler_name`!
              // So we just store `new_bowler_name` in a ref or state and send it with the NEXT ball.
              // For simplicity, let's just save it.
              setScoringAction({ type: 'PENDING_NEW_BOWLER', name: newB });
            }}>Next Over</button>
          </div>
        </div>
      )}
      
      {scoringAction?.type === 'PENDING_NEW_BOWLER' && (
         <div className="p-4 bg-indigo-50 text-indigo-800 text-center text-sm font-bold animate-pulse">
           Next bowler ({scoringAction.name}) will be recorded on the next ball.
         </div>
      )}
    </div>
  );
}
