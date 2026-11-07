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

#include <optional>

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

	// One giver -> receiver pair, fed one PPA frame at a time: picks the depth
	// the detector reads and caps how often a beat may fire.
	class ThrustWatch
	{
	public:
		// The detector used to see one sample per sfx.velocitypoll (0.1 s by
		// default), which capped beats at that rate; frames come far faster, so
		// jitter above a low hysteresis could fire a beat per frame. A beat closer
		// than this to the last one is not sent (the detector still advances).
		static constexpr double kMinBeatGap = 0.1;

		explicit ThrustWatch(float a_turn) :
			_turn(a_turn) {}

		float Turn() const { return _turn; }

		// The receiver's interaction ended: the next frame starts a new run.
		void Reset()
		{
			_detector.Reset();
			_ownSeen = false;
		}

		// a_own = the giver's own depth when PPA lists the giver among the
		// receiver's partners this frame, else nullopt; a_deepest = the
		// receiver's deepest. Until PPA has listed the giver once, the watch reads
		// the deepest (one number per receiver, as before 0.7.10). From then on it
		// reads only the giver's own, and a frame without it is skipped: switching
		// back and forth between two partners' depths would read as strokes.
		ThrustDetector::Result Feed(const std::optional<float>& a_own, float a_deepest, double a_now)
		{
			float depth = a_deepest;
			if (a_own) {
				if (!_ownSeen) {
					_ownSeen = true;
					_detector.Reset();  // a new signal: no stroke runs across the switch
				}
				depth = *a_own;
			} else if (_ownSeen) {
				return {};
			}
			_depth = depth;
			auto result = _detector.Step(depth, a_now, _turn);
			if (result.beat != ThrustDetector::Beat::None) {
				if (a_now - _lastBeatAt < kMinBeatGap) {
					result.beat = ThrustDetector::Beat::None;
				} else {
					_lastBeatAt = a_now;
				}
			}
			return result;
		}

		float LastDepth() const { return _depth; }  // what the last fed frame read, for the log text

	private:
		ThrustDetector _detector;
		float          _turn;
		bool           _ownSeen = false;
		float          _depth = 0.0f;
		double         _lastBeatAt = -1.0e9;
	};
}
