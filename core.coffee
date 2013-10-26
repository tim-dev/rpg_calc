
uuid = () ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
        r = Math.random()*16|0
        v = if c == 'x' then r else r&0x3 or 0x8
        return v.toString(16)


roll_dice = (dice) ->
    return dice if typeof dice == "int"
    return parseInt(dice) if dice.indexOf('d') == -1

    # TODO Bonus dice!

    [num, die] = dice.split("d")
    num = parseInt(num)
    die = parseInt(die)
    i = total = 0
    while i < num
        roll = Math.ceil(Math.random() * die)
        total += roll
        i++
    return total
        

class Entity
    constructor: (options) ->
        for k, v of options
            @[k] = v

        @name or= "New entity"
        @cur_hit_points or= @max_hit_points or 10
        @max_hit_points or= @cur_hit_points

        @armor_class or= 10
        @armor_reduction or= 0

        @weapon_hit_dice or= "1d20"
        @weapon_damage or= "1d12"
        @bonus_hit or= 0
        @bonus_damage or= 0

        # To get animations working
        @adding = true
        setTimeout () =>
            @adding = false
        , 1000


    attack: (defender, options={}) ->
        # TODO Criticals!
        # Roll dice
        roll = if options.roll then options.roll else roll_dice(@weapon_hit_dice)
        roll += options.hit_modifier or 0

        hit = roll > defender.armor_class
        return { hit: hit, roll: roll } unless hit

        # EXTRA STUFF FOR GAME OF THRONES
        degree = 1
        if options.use_degree
            degree = Math.ceil((roll - defender.armor_class) / 5)
        
        # Calculate damage
        base_damage = roll_dice(@weapon_damage) + @bonus_damage
        given_damage = (degree * base_damage) - defender.armor_reduction

        # Apply damage
        defender.damage(given_damage)
        
        return {
            hit: hit
            roll: roll
            degree: degree
            base_damage: base_damage
            given_damage: given_damage
        }

    damage: (damage=0) ->
        @cur_hit_points -= if damage < 0 then 0 else damage

    heal: (healing=0) ->
        @cur_hit_points += if healing < 0 then 0 else healing


app = angular.module('app', [])

app.directive 'entity', () ->
    return {
        restrict: "E"
        replace: true
        scope: {entity: "=", click: "="}
        templateUrl: "entity.html"
        controller: ($scope, $element, $attrs) ->
            $($element).draggable()
            
            $scope.hit_point_color = () ->
                hp = $scope.entity.cur_hit_points
                if hp < 1
                    return "red"
                else if hp < 0.33 * $scope.entity.max_hit_points
                    return "yellow"
                return ""
    }


make_entity = (options={}) ->
    options.uuid = uuid()
    return new Entity(options)


window.MainController = ($scope, $timeout) ->
    $scope.entities = []
    $scope.results = []
    $scope.ruleset = "d&d"
    $scope.attack_options = {}
    entity_counter = 0


    $scope.add_entity = () ->
        ent = make_entity({name: "entity#{ entity_counter++ }"})
        $scope.entities.push(ent)
        $scope.editee = ent


    $scope.edit_entity = ($event, entity) ->
        console.log entity
        $event.stopPropagation()
        $scope.editee = entity
        $scope.clear_attack()

        $("#entity_modal").modal("show")


    $scope.remove_entity = ($event, entity) ->
        $event.stopPropagation()

        entity.removing = true
        $timeout () ->
            $scope.entities.splice($scope.entities.indexOf(entity), 1)
        , 1000


    $scope.get_attack_options = () ->
        switch $scope.ruleset
            when 'd&d'
                return {}
            when 'got'
                return { use_degree: true }
            else
                return {}


    $scope.set_combatant = (entity) ->
        # If attacker
        unless $scope.attacker
            $scope.attacker = entity
        else
            $scope.defender = entity

            if $scope.attacker.uuid == $scope.defender.uuid
                $scope.clear_attack()
                return null

            # Show the modal to get more information
            $("#attack_modal").modal("show")


    $scope.clear_attack = () ->
        # Clear out the attack data
        $scope.attacker = null
        $scope.defender = null
        $scope.attack_options = {}


    $scope.do_attack = () ->
        # Basic options, related to the current ruleset
        angular.extend($scope.attack_options, $scope.get_attack_options())

        result = $scope.attacker.attack($scope.defender, $scope.attack_options)
        result.attacker = $scope.attacker
        result.defender = $scope.defender
        console.log result
        $scope.results.push(result)

        $scope.clear_attack()


    $scope.remove_attack = (result) ->
        result.defender.heal(result.given_damage)
        $scope.results.splice($scope.results.indexOf(result), 1)

