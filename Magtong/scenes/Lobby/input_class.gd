extends Object

# a class representing Player input
class player_input:
    enum type {
        ## Vector2
        move,
        ## Button (bool)
        pos_charge, 
        ## Button (bool)
        neg_charge, 
        ## Button (bool)
        pulse, 
        ## Button (bool)
        cancel, 
        ## Button (bool)
        start 
    }
    func _init(input: type, value:bool):
        self.input = input
        self.value_bool = null
        self.value_vector2 = null
        if input == type.move:
            self.value_vector2 = value
        else:
            self.value_bool  = value


