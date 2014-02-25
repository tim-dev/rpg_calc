
uuid = () ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
        r = Math.random()*16|0
        v = if c == 'x' then r else r&0x3 or 0x8
        return v.toString(16)


roll_dice = (roll_string) ->
    ###
    Example roll strings:
    1d6
    1d8 + 8
    1d8 + 2d4 + 3
    ###
    
    # TODO more operations!
    dice_parts = roll_string.split(/\ *\+\ */g)

    roll = 0
    roll_parts = []
    for dice in dice_parts
        roll_part = _roll_die(dice)
        roll_parts.push("#{ dice } - #{ roll_part }", )
        roll += roll_part
    console.log "Rolled a #{ roll_string }, parts were #{ roll_parts }"

    return roll


_roll_die = (dice) ->
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
    constructor: (options={}) ->
        for k, v of options
            this[k] = v

        @name            or= "New entity"
        @cur_hit_points  or= @max_hit_points or 10
        @max_hit_points  or= @cur_hit_points

        @armor_class     or= 10
        @armor_reduction or= 0

        @weapons         or= []
        @weapons = @weapons.map (w) -> new Weapon(w)

        @checks          or= {}

        # To get animations working
        @adding = true
        setTimeout () =>
            @adding = false
        , 1000

    damage: (damage=0) ->
        @cur_hit_points -= if damage < 0 then 0 else damage

    heal: (healing=0) ->
        @cur_hit_points += if healing < 0 then 0 else healing


class Weapon

    constructor: (options={}) ->
        for k, v of options
            this[k] = v


    attack: (defender, options={}) ->
        # TODO Criticals!
        # Roll dice
        if options.roll
            roll = parseInt(options.roll)

            # Parse the bonus from the hit dice
            bonus = /\ *[+-]\d(?!n)/.exec(@hit_dice)
            roll += parseInt(bonus[0]) if bonus
        else
            roll = roll_dice(@hit_dice)

        roll += options.hit_modifier or 0

        hit = roll > defender.armor_class
        return { hit: hit, roll: roll } unless hit

        # EXTRA STUFF FOR GAME OF THRONES
        degree = 1
        if options.use_degree
            degree = Math.ceil((roll - defender.armor_class) / 5)
        
        # Calculate damage
        base_damage = roll_dice(@damage)
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


make_entity = (options={}) ->
    options.uuid or= uuid()
    return new Entity(options)


app = angular.module('app', [])
    .directive 'entity', () ->
        return {
            restrict: "E"
            replace: true
            scope: {entity: "="}
            templateUrl: "entity.html"
            controller: ($scope, $element, $attrs) ->
                $($element).draggable(
                    distance: 10
                    delay: 100
                    zIndex: 100
                ).on "click", () ->
                    $scope.$apply (scope) ->
                        scope.$parent.set_combatant(scope.entity)
                
                $scope.hit_point_color = () ->
                    hp = $scope.entity.cur_hit_points
                    if hp < 1
                        return "red"
                    else if hp < 0.5 * $scope.entity.max_hit_points
                        return "yellow"
                    return ""
        }
    .directive 'entitybasics', () ->
        return {
            restrict: "E"
            replace: true
            scope: {entity: "="}
            templateUrl: "entity_basics.html"
        }
    .directive 'ddentity', () ->
        return {
            restrict: "E"
            replace: true
            scope: {entity: "="}
            templateUrl: "ddentity.html"
            controller: ($scope, $element, $attrs) ->
                $scope.add_weapon = () ->
                    $scope.entity.weapons.push(new Weapon())
                $scope.fix_hit_dice = (weapon) ->
                    weapon.hit_dice = "1d20+" + weapon.attack_bonus
                    console.log weapon.hit_dice
        }
    .controller 'MainController', ['$scope', '$timeout', ($scope, $timeout) ->
        $scope.entities = []
        $scope.results = []
        $scope.ruleset = "d&d"
        $scope.attack_options = {}
        $scope.saved_checks = []
        $scope.current_check = {}
        entity_counter = 0

        $scope.angular = angular


        $scope.save = () ->
            blob = new Blob([angular.toJson($scope.entities)], {type: "application/json;charset=utf-8"})
            saveAs(blob, "rpg.json")


        $scope.load = () ->
            $("#load_file").trigger("click")
            return


        $("#load_file").on "change", () ->
            file = @files[0]
            return unless file

            reader = new FileReader()
            reader.readAsText(file, "UTF-8")

            reader.onload = (evt) ->
                entities = JSON.parse(evt.target.result)
                entities.map (e) ->
                    ent = make_entity(e)
                    $scope.$apply (scope) -> scope.entities.push(ent)

            reader.onerror = (evt) ->
                console.error "error loading file"

        # Focus on the proper thing when the modal is shown
        $("#attack_modal").on "shown", () ->
            setTimeout () ->
                $("#attack_modal input[name='custom_roll']").focus()
            , 1

        $scope.save_check = (check) ->
            for c, i in $scope.saved_checks
                if c.name == check.name
                    $scope.saved_checks[i] = check
                    return
            $scope.saved_checks.push(angular.extend({}, check))


        $scope.roll_check = (check) ->
            console.log check
            check_results = []
            for e in check.entities
                res = roll_dice("1d20+" + (e.checks[check.type] or 0))
                console.log "Rolled ", "1d20+" + (e.checks[check.type] or 0), " and got a ", res
                check_results.push(roll: res, name: e.name)
            check_results.sort (a, b) -> a.roll < b.roll
            $scope.results.unshift(type: "check", name: check.name || check.type, checks: check_results)


        $scope.add_entity = () ->
            ent = make_entity({name: "entity#{ entity_counter++ }"})
            $scope.entities.push(ent)
            $scope.editee = ent


        $scope.edit_entity = ($event, entity) ->
            $event.stopPropagation()
            $scope.editee = entity
            $scope.clear_attack()

            $("#entity_modal").modal("show")
            return


        $scope.remove_entity = ($event, entity) ->
            $event.stopPropagation()

            # Cute animation
            entity.removing = true
            $timeout () ->
                delete $scope.entities.splice($scope.entities.indexOf(entity), 1)
            , 500


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
                if entity.weapons.length and entity.weapons.indexOf(entity.chosen_weapon) == -1
                    entity.chosen_weapon = entity.weapons[0]
                $scope.attacker = entity
            else
                $scope.defender = entity

                if $scope.attacker.uuid == $scope.defender.uuid
                    $scope.clear_attack()
                    return null

                # Show the modal to get more information
                $("#attack_modal").modal("show")
                return


        $scope.clear_attack = () ->
            # Clear out the attack data
            $scope.attacker = null
            $scope.defender = null
            $scope.attack_options = {}


        $scope.do_attack = () ->
            # Basic options, related to the current ruleset
            angular.extend($scope.attack_options, $scope.get_attack_options())

            result = $scope.attacker.chosen_weapon.attack($scope.defender, $scope.attack_options)
            result.attacker = $scope.attacker
            result.defender = $scope.defender
            result.type = 'attack'
            console.log result
            $scope.results.unshift(result)
            $("#attack_modal").modal("hide")

            $scope.clear_attack()


        $scope.remove_attack = (result) ->
            result.defender.heal(result.given_damage)
            delete $scope.results.splice($scope.results.indexOf(result), 1)
    ]

