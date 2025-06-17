import React, { useState } from 'react';

const BusRoutes = () => {
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [results, setResults] = useState([]);
  const [error, setError] = useState('');

  const searchRoutes = async () => {
    if (!start || !end) return setError("Please enter both stops");

    try {
      const res = await fetch(`http://localhost:8000/api/routes/search_path/?start=${start}&end=${end}`);
      const data = await res.json();

      if (!res.ok) throw new Error(data.error || data.message || "Search failed");

      setResults(data);
      setError('');
    } catch (err) {
      setResults([]);
      setError(err.message);
    }
  };

  return (
    <div className="p-4 max-w-xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Search Bus Route</h2>
      <input
        type="text"
        value={start}
        onChange={(e) => setStart(e.target.value)}
        placeholder="Enter start stop"
        className="border p-2 mb-2 w-full"
      />
      <input
        type="text"
        value={end}
        onChange={(e) => setEnd(e.target.value)}
        placeholder="Enter end stop"
        className="border p-2 mb-2 w-full"
      />
      <button
        onClick={searchRoutes}
        className="bg-blue-600 text-white px-4 py-2 rounded mb-4"
      >
        Search
      </button>

      {error && <p className="text-red-500">{error}</p>}

      {results.map((route, idx) => (
        <div key={idx} className="border p-3 my-2 rounded bg-gray-100">
          <h3 className="font-bold text-lg mb-1">Route: {route.route_number}</h3>
          <p>Stops:</p>
          <ul className="list-disc ml-6">
            {route.sub_path.map((stop, i) => (
              <li key={i}>{stop}</li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
};

export default BusRoutes;
