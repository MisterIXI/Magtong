extends AbilityBase
class_name impulse

@export var cd_timer: Timer
signal impulse_emitted(pulse_position: Vector2, pol: PlayerBody.polarity)


func _ability_button_down():
	if cd_timer.is_stopped() and player.state != player.polarity.IDLE:
		cd_timer.start(self.settings.impulse_cooldown)
		for puck in map.pucks:
			var puck_pol = PlayerBody.polarity.POS if puck.is_plus_pol else PlayerBody.polarity.NEG
			var mult = 1 if puck_pol == player.state else - 1
			var dist = puck.global_position.distance_to(player.global_position)
			var force = self.settings.magnet_dropoff.sample(dist / self.settings.magnet_range)
			var scaled_force = (
				(puck.global_position - player.global_position).normalized() * force * self.settings.magnet_force * mult * self.settings.impulse_mult
			)
			puck.apply_impulse(scaled_force)
		rpc_impulse_signal.rpc(player.global_position, player.state)

func emit_pulse(pulse_position: Vector2, pol: PlayerBody.polarity):
	for puck in map.pucks:
		var puck_pol = PlayerBody.polarity.POS if puck.is_plus_pol else PlayerBody.polarity.NEG
		var mult = 1 if puck_pol == pol else - 1
		var dist = puck.global_position.distance_to(pulse_position)
		var force = self.settings.magnet_dropoff.sample(dist / self.settings.magnet_range)
		var scaled_force = ((puck.global_position - pulse_position).normalized() * force * self.settings.magnet_force * mult * self.settings.impulse_mult)

		puck.apply_impulse(scaled_force)

@rpc("authority", "call_local", "reliable")
func rpc_impulse_signal(pulse_position: Vector2, pol: PlayerBody.polarity):
	impulse_emitted.emit(pulse_position, pol)

func _ability_reset():
	cd_timer.stop()