
String.prototype.toTitleCase = () ->
    return this.replace /\w\S*/g, (txt) -> return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()

uuid = () ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
        r = Math.random()*16|0
        v = if c == 'x' then r else r&0x3 or 0x8
        return v.toString(16)

remove_spaces = (txt) ->
    return '' unless txt
    txt.replace(/\s/g, '')

window.roll_dice = (roll_string) ->
    ###
    Example roll strings:
    1d6
    1d8 + 8
    1d4 - 1
    1d8 + 2d4 + 3
    ###

    # TODO more operations!
    dice_parts = roll_string.match(/.+?(?=[+-]|$)/g)
    #dice_parts = roll_string.split(/\ *\+\ */g)

    roll = 0
    roll_parts = []
    for dice in dice_parts
        roll_part = _roll_die(dice)
        roll_parts.push("#{ dice } => #{ roll_part }", )
        roll += roll_part
    console.log "Rolled a #{ roll_string }, parts were #{ roll_parts }"

    return roll


_roll_die = (dice) ->
    return dice if typeof dice == "int"
    return parseInt(dice) unless /d/i.test(dice)

    # TODO Bonus dice!
    [num, die] = dice.split(/d/i)
    num = parseInt(num)
    die = parseInt(die)
    total = 0
    for i in [0...num]
        roll = Math.ceil(Math.random() * die)
        total += roll
    return if num < 0 then total * -1 else total


class Entity
    @defaults =
        name            : "New entity"
        cur_hit_points  : 10
        max_hit_points  : 10

        armor_class     : 10
        armor_reduction : 0

        weapons         : []
        checks          : {}

    constructor: (options={}) ->
        for k, v of angular.extend({}, Entity.defaults, options)
            this[k] = v

        @weapons = @weapons.map (w) -> if w.constructor.name == "Weapon" then w else new Weapon(w)
        @uuid    = uuid()

    damage: (damage=0) ->
        @cur_hit_points -= if damage < 0 then 0 else damage

    heal: (healing=0) ->
        @cur_hit_points += if healing < 0 then 0 else healing


class Weapon
    @defaults =
        hit_dice: "1d20"
        critical: "x2"
        attack_bonus: "0"
        #damage: "1d6"

    constructor: (options={}) ->
        angular.extend(this, Weapon.defaults, options)

        # Temp fix for old style
        if @hit_dice
            dice = remove_spaces(@hit_dice).match(/1d20(?:\s*[+-]\s*)(\d+)?/i)
            if dice
                @hit_dice = "1d20"
                @attack_bonus = dice[1]

    attack: (defender, options={}) ->
        # Sanitize options
        options.roll
        options.hit_modifier

        # Roll dice
        roll = if options.roll then parseInt(options.roll) else roll_dice(@hit_dice)
        return alert("Invalid roll: #{ options.roll }") if isNaN(roll)

        # Criticals!
        crit = false
        crit_multi = 1
        if @critical
            [full, crit_roll, crit_multi] = (@critical or '').match(/(\d+)?(?:\-20)?x(\d)/i)
            crit_roll = if crit_roll then parseInt(crit_roll) else 20
            crit = @hit_dice is "1d20" and roll >= crit_roll
            crit_multi = if crit then parseInt(crit_multi) else 1

        # Parse the bonus from the hit dice
        roll += parseInt(@attack_bonus or 0)
        roll += parseInt(options.hit_modifier or 0)

        hit = crit or roll > defender.armor_class
        return { hit: hit, roll: roll } unless hit

        # EXTRA STUFF FOR GAME OF THRONES
        degree = 1
        if options.use_degree
            degree = Math.ceil((roll - defender.armor_class) / 5)

        # Calculate damage
        base_damage = roll_dice(@damage)
        given_damage = (degree * base_damage * crit_multi) - defender.armor_reduction

        # Apply damage
        defender.damage(given_damage)

        return {
            hit: hit
            crit: crit
            crit_multi: crit_multi
            roll: roll
            degree: degree
            base_damage: base_damage
            given_damage: given_damage
        }


app = angular.module('app', ['ui.sortable'])
    .factory('debounce', ['$timeout', ($timeout) ->
        timer = null
        return (callback, ms) ->
            $timeout.cancel(timer) if timer
            timer = $timeout(callback, ms)
    ])
    .directive 'entity', () ->
        return {
            restrict: "E"
            replace: true
            scope: false
            templateUrl: "entity.html"
            controller: ($scope, $element, $attrs) ->
                $element.on "click", (e) ->
                    return if $(e.toElement).is("a.dropdown-toggle, a > i, a > b, ul.dropdown-menu li, ul.dropdown-menu li > a")
                    $scope.$apply (scope) ->
                        scope.$root.set_combatant(scope.entity)

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
                    weapon.hit_dice = "1d20" #+ weapon.attack_bonus
        }
    .controller 'MainController', ['$rootScope', '$timeout', ($scope, $timeout) ->
        $scope.entities = [
            name: "Players"
            members: []
        ,
            name: "Enemies"
            members: []
        ,
            name: "NPCs"
            members: []
        ]
        entity_counter         = 0
        $scope.angular         = angular
        $scope.ruleset         = "d&d"
        $scope.check_types     = ['listen', 'spot', 'fortitude', 'reflex', 'will']
        $scope.results         = []
        $scope.attack_options  = {}
        $scope.sortableOptions =
            connectWith: ".entities"
            revert: true
            delay: 100
            distance: 10
            start: (event, ui) ->
                # Kill the click that happens on mouseup
                $(event.toElement).one 'click', (e) -> e.stopImmediatePropagation()


        $scope.roll_check = (check) ->
            console.log check
            check_results = []
            for e in check.entities
                res = roll_dice("1d20+" + (e.checks[check.type] or 0))
                console.log "Rolled ", "1d20+" + (e.checks[check.type] or 0), " and got a ", res
                check_results.push(roll: res, name: e.name)
            check_results.sort (a, b) -> a.roll < b.roll
            $scope.results.unshift(type: "check", name: check.name || check.type.toTitleCase(), checks: check_results)


        $scope.make_entity = (options={}) ->
            e = new Entity(options)

            # To get animations working
            e.adding = true
            $timeout () ->
                e.adding = false
            , 1000
            return e


        $scope.get_group = (group_name) ->
            for group in $scope.entities
                return group if group.name == group_name
            return null


        $scope.extend_entities = (ent_groups) ->
            for _group in ent_groups
                group = $scope.get_group(_group.name)

                if group
                    group.members = group.members.concat(_group.members)
                else
                    $scope.entities.push _group
            return

        $scope.heal_all = (members) ->
            m.cur_hit_points = m.max_hit_points for m in members

        $scope.clear_members = (group) ->
            return unless confirm "Are you sure you want to delete all the #{ group.name.toLowerCase() }?"
            group.members = []


        $scope.add_entity = (group_name="Players") ->
            ent = $scope.make_entity({name: "entity#{ entity_counter++ }"})
            $scope.get_group(group_name).members.push(ent)
            $scope.edit_entity(ent)


        $scope.edit_entity = ($event, entity) ->
            if entity
                $event.stopPropagation()
            else
                entity = $event
                $event = null

            $scope.editee = entity
            $scope.clear_attack()

            $("#entity_modal").modal("show")
            return


        $scope.copy_entity = ($event, i, ent) ->
            e = angular.copy(ent)
            e.uuid = null
            $scope.entities[i].members.push($scope.make_entity(e))


        $scope.remove_entity = ($event, gi, i, entity) ->
            $event.stopPropagation()

            # Cute animation
            entity.removing = true
            $timeout () ->
                delete $scope.entities[gi].members.splice(i, 1)
            , 500


        $scope.get_attack_options = () ->
            options = {ruleset: $scope.ruleset}
            switch $scope.ruleset
                #when 'd&d'
                when 'got'
                    options.use_degree = true
            return options


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
                results = JSON.parse(evt.target.result)

                # The new style
                for group in results
                    group.members = group.members.map (e) -> return new Entity(e)
                $scope.$apply (scope) -> scope.extend_entities(results)


            reader.onerror = (evt) ->
                console.error "error loading file"

        # Focus on the proper thing when the modal is shown
        $("#attack_modal").on "shown", () ->
            setTimeout () ->
                $("#attack_modal input[name='custom_roll']").focus()
            , 1
    ]

