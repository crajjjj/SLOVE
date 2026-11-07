#pragma once

// The thrust turn detector, fed one Accurate Penetration depth sample at a time.
// Depth rising is the thrust going in, depth falling is the pull-out, and the turn
// between the two is the moment of impact. A turn counts once the depth has come
// back by a_turn from its extreme: that hysteresis keeps jitter around a held-deep
// pose from firing claps, at the price of hearing each turn that much late.
//
// It used to run in SLOVE_SFX (PPAThrustStep, polled every sfx.velocitypoll); here
// it sees every frame PPA reports, for one giver-receiver pair. The logic is the
// Papyrus one unchanged.

namespace Core
{
	class ThrustDetector
	{
	public:
		enum class Beat
		{
			None,
			Impact,   // turned at its deepest after a stroke of at least a_turn
			Reentry   // turned back in
		};

		struct Result
		{
			Beat  beat = Beat::None;
			float timeToThrust = 0.0f;  // seconds the last inward stroke took
			float stroke = 0.0f;        // how far it travelled (Impact only)
		};

		// Forget the run: the next sample starts a new one.
		void Reset() { _primed = false; }

		Result Step(float a_depth, double a_now, float a_turn)
		{
			Result result;
			if (!_primed) {
				// the first sample of a run only sets the extremes: there is no
				// stroke behind it to sound yet
				_primed = true;
				_rising = true;
				_peak = _trough = a_depth;
				_peakAt = _troughAt = a_now;
				return result;
			}
			if (_rising) {
				if (a_depth > _peak) {
					_peak = a_depth;
					_peakAt = a_now;
				} else if (_peak - a_depth >= a_turn) {
					// turned at the peak. The stroke that led there began at the trough
					const float stroke = _peak - _trough;
					_lastTime = static_cast<float>(_peakAt - _troughAt);
					_rising = false;
					_trough = a_depth;
					_troughAt = a_now;
					if (stroke >= a_turn) {
						result.beat = Beat::Impact;
						result.timeToThrust = _lastTime;
						result.stroke = stroke;
					}
				}
			} else if (a_depth < _trough) {
				_trough = a_depth;
				_troughAt = a_now;
			} else if (a_depth - _trough >= a_turn) {
				// heading back in
				_rising = true;
				_peak = a_depth;
				_peakAt = a_now;
				result.beat = Beat::Reentry;
				result.timeToThrust = _lastTime;
			}
			return result;
		}

	private:
		bool   _primed = false;
		bool   _rising = true;
		float  _peak = 0.0f;
		float  _trough = 0.0f;
		double _peakAt = 0.0;
		double _troughAt = 0.0;
		float  _lastTime = 0.0f;  // how long the last inward stroke took
	};
}
