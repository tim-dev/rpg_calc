// Generated by CoffeeScript 1.9.1
(function() {
  var Entity, Weapon, _roll_die, app, remove_spaces, uuid;

  String.prototype.toTitleCase = function() {
    return this.replace(/\w\S*/g, function(txt) {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
  };

  uuid = function() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r, v;
      r = Math.random() * 16 | 0;
      v = c === 'x' ? r : r & 0x3 || 0x8;
      return v.toString(16);
    });
  };

  remove_spaces = function(txt) {
    if (!txt) {
      return '';
    }
    return txt.replace(/\s/g, '');
  };

  window.roll_dice = function(roll_string) {

    /*
    Example roll strings:
    1d6
    1d8 + 8
    1d4 - 1
    1d8 + 2d4 + 3
     */
    var dice, dice_parts, j, len, roll, roll_part, roll_parts;
    dice_parts = roll_string.match(/.+?(?=[+-]|$)/g);
    roll = 0;
    roll_parts = [];
    for (j = 0, len = dice_parts.length; j < len; j++) {
      dice = dice_parts[j];
      roll_part = _roll_die(dice);
      roll_parts.push(dice + " => " + roll_part);
      roll += roll_part;
    }
    console.log("Rolled a " + roll_string + ", parts were " + roll_parts);
    return roll;
  };

  _roll_die = function(dice) {
    var die, i, j, num, ref, ref1, roll, total;
    if (typeof dice === "int") {
      return dice;
    }
    if (!/d/i.test(dice)) {
      return parseInt(dice);
    }
    ref = dice.split(/d/i), num = ref[0], die = ref[1];
    num = parseInt(num);
    die = parseInt(die);
    total = 0;
    for (i = j = 0, ref1 = num; 0 <= ref1 ? j < ref1 : j > ref1; i = 0 <= ref1 ? ++j : --j) {
      roll = Math.ceil(Math.random() * die);
      total += roll;
    }
    if (num < 0) {
      return total * -1;
    } else {
      return total;
    }
  };

  Entity = (function() {
    Entity.defaults = {
      name: "New entity",
      cur_hit_points: 10,
      max_hit_points: 10,
      armor_class: 10,
      armor_reduction: 0,
      weapons: [],
      checks: {}
    };

    function Entity(options) {
      var k, ref, v;
      if (options == null) {
        options = {};
      }
      ref = angular.extend({}, Entity.defaults, options);
      for (k in ref) {
        v = ref[k];
        this[k] = v;
      }
      this.weapons = this.weapons.map(function(w) {
        if (w.constructor.name === "Weapon") {
          return w;
        } else {
          return new Weapon(w);
        }
      });
      this.uuid = uuid();
    }

    Entity.prototype.damage = function(damage) {
      if (damage == null) {
        damage = 0;
      }
      return this.cur_hit_points -= damage < 0 ? 0 : damage;
    };

    Entity.prototype.heal = function(healing) {
      if (healing == null) {
        healing = 0;
      }
      return this.cur_hit_points += healing < 0 ? 0 : healing;
    };

    return Entity;

  })();

  Weapon = (function() {
    Weapon.defaults = {
      hit_dice: "1d20",
      critical: "x2",
      attack_bonus: "0"
    };

    function Weapon(options) {
      var dice;
      if (options == null) {
        options = {};
      }
      angular.extend(this, Weapon.defaults, options);
      if (this.hit_dice) {
        dice = remove_spaces(this.hit_dice).match(/1d20(?:\s*[+-]\s*)(\d+)?/i);
        if (dice) {
          this.hit_dice = "1d20";
          this.attack_bonus = dice[1];
        }
      }
    }

    Weapon.prototype.attack = function(defender, options) {
      var base_damage, crit, crit_multi, crit_roll, degree, full, given_damage, hit, ref, roll;
      if (options == null) {
        options = {};
      }
      options.roll;
      options.hit_modifier;
      roll = options.roll ? parseInt(options.roll) : roll_dice(this.hit_dice);
      if (isNaN(roll)) {
        return alert("Invalid roll: " + options.roll);
      }
      crit = false;
      crit_multi = 1;
      if (this.critical) {
        ref = (this.critical || '').match(/(\d+)?(?:\-20)?x(\d)/i), full = ref[0], crit_roll = ref[1], crit_multi = ref[2];
        crit_roll = crit_roll ? parseInt(crit_roll) : 20;
        crit = this.hit_dice === "1d20" && roll >= crit_roll;
        crit_multi = crit ? parseInt(crit_multi) : 1;
      }
      roll += parseInt(this.attack_bonus || 0);
      roll += parseInt(options.hit_modifier || 0);
      hit = crit || roll > defender.armor_class;
      if (!hit) {
        return {
          hit: hit,
          roll: roll
        };
      }
      degree = 1;
      if (options.use_degree) {
        degree = Math.ceil((roll - defender.armor_class) / 5);
      }
      base_damage = roll_dice(this.damage);
      given_damage = (degree * base_damage * crit_multi) - defender.armor_reduction;
      defender.damage(given_damage);
      return {
        hit: hit,
        crit: crit,
        crit_multi: crit_multi,
        roll: roll,
        degree: degree,
        base_damage: base_damage,
        given_damage: given_damage
      };
    };

    return Weapon;

  })();

  app = angular.module('app', ['ui.sortable']).factory('debounce', [
    '$timeout', function($timeout) {
      var timer;
      timer = null;
      return function(callback, ms) {
        if (timer) {
          $timeout.cancel(timer);
        }
        return timer = $timeout(callback, ms);
      };
    }
  ]).directive('entity', function() {
    return {
      restrict: "E",
      replace: true,
      scope: false,
      templateUrl: "entity.html",
      controller: function($scope, $element, $attrs) {
        $element.on("click", function(e) {
          if ($(e.toElement).is("a.dropdown-toggle, a > i, a > b, ul.dropdown-menu li, ul.dropdown-menu li > a")) {
            return;
          }
          return $scope.$apply(function(scope) {
            return scope.$root.set_combatant(scope.entity);
          });
        });
        return $scope.hit_point_color = function() {
          var hp;
          hp = $scope.entity.cur_hit_points;
          if (hp < 1) {
            return "red";
          } else if (hp < 0.5 * $scope.entity.max_hit_points) {
            return "yellow";
          }
          return "";
        };
      }
    };
  }).directive('entitybasics', function() {
    return {
      restrict: "E",
      replace: true,
      scope: {
        entity: "="
      },
      templateUrl: "entity_basics.html"
    };
  }).directive('ddentity', function() {
    return {
      restrict: "E",
      replace: true,
      scope: {
        entity: "="
      },
      templateUrl: "ddentity.html",
      controller: function($scope, $element, $attrs) {
        $scope.add_weapon = function() {
          return $scope.entity.weapons.push(new Weapon());
        };
        return $scope.fix_hit_dice = function(weapon) {
          return weapon.hit_dice = "1d20";
        };
      }
    };
  }).controller('MainController', [
    '$rootScope', '$timeout', function($scope, $timeout) {
      var entity_counter;
      $scope.entities = [
        {
          name: "Players",
          members: []
        }, {
          name: "Enemies",
          members: []
        }, {
          name: "NPCs",
          members: []
        }
      ];
      entity_counter = 0;
      $scope.angular = angular;
      $scope.ruleset = "d&d";
      $scope.check_types = ['listen', 'spot', 'fortitude', 'reflex', 'will'];
      $scope.results = [];
      $scope.attack_options = {};
      $scope.sortableOptions = {
        connectWith: ".entities",
        revert: true,
        delay: 100,
        distance: 10,
        start: function(event, ui) {
          return $(event.toElement).one('click', function(e) {
            return e.stopImmediatePropagation();
          });
        }
      };
      $scope.roll_check = function(check) {
        var check_results, e, j, len, ref, res;
        console.log(check);
        check_results = [];
        ref = check.entities;
        for (j = 0, len = ref.length; j < len; j++) {
          e = ref[j];
          res = roll_dice("1d20+" + (e.checks[check.type] || 0));
          console.log("Rolled ", "1d20+" + (e.checks[check.type] || 0), " and got a ", res);
          check_results.push({
            roll: res,
            name: e.name
          });
        }
        check_results.sort(function(a, b) {
          return a.roll < b.roll;
        });
        return $scope.results.unshift({
          type: "check",
          name: check.name || check.type.toTitleCase(),
          checks: check_results
        });
      };
      $scope.make_entity = function(options) {
        var e;
        if (options == null) {
          options = {};
        }
        e = new Entity(options);
        e.adding = true;
        $timeout(function() {
          return e.adding = false;
        }, 1000);
        return e;
      };
      $scope.get_group = function(group_name) {
        var group, j, len, ref;
        ref = $scope.entities;
        for (j = 0, len = ref.length; j < len; j++) {
          group = ref[j];
          if (group.name === group_name) {
            return group;
          }
        }
        return null;
      };
      $scope.extend_entities = function(ent_groups) {
        var _group, group, j, len;
        for (j = 0, len = ent_groups.length; j < len; j++) {
          _group = ent_groups[j];
          group = $scope.get_group(_group.name);
          if (group) {
            group.members = group.members.concat(_group.members);
          } else {
            $scope.entities.push(_group);
          }
        }
      };
      $scope.add_entity = function(group_name) {
        var ent;
        if (group_name == null) {
          group_name = "Players";
        }
        ent = $scope.make_entity({
          name: "entity" + (entity_counter++)
        });
        $scope.get_group(group_name).members.push(ent);
        return $scope.edit_entity(ent);
      };
      $scope.edit_entity = function($event, entity) {
        if (entity) {
          $event.stopPropagation();
        } else {
          entity = $event;
          $event = null;
        }
        $scope.editee = entity;
        $scope.clear_attack();
        $("#entity_modal").modal("show");
      };
      $scope.copy_entity = function($event, i, ent) {
        var e;
        e = angular.copy(ent);
        e.uuid = null;
        return $scope.entities[i].members.push($scope.make_entity(e));
      };
      $scope.remove_entity = function($event, gi, i, entity) {
        $event.stopPropagation();
        entity.removing = true;
        return $timeout(function() {
          return delete $scope.entities[gi].members.splice(i, 1);
        }, 500);
      };
      $scope.get_attack_options = function() {
        var options;
        options = {
          ruleset: $scope.ruleset
        };
        switch ($scope.ruleset) {
          case 'got':
            options.use_degree = true;
        }
        return options;
      };
      $scope.set_combatant = function(entity) {
        if (!$scope.attacker) {
          if (entity.weapons.length && entity.weapons.indexOf(entity.chosen_weapon) === -1) {
            entity.chosen_weapon = entity.weapons[0];
          }
          return $scope.attacker = entity;
        } else {
          $scope.defender = entity;
          if ($scope.attacker.uuid === $scope.defender.uuid) {
            $scope.clear_attack();
            return null;
          }
          $("#attack_modal").modal("show");
        }
      };
      $scope.clear_attack = function() {
        $scope.attacker = null;
        $scope.defender = null;
        return $scope.attack_options = {};
      };
      $scope.do_attack = function() {
        var result;
        angular.extend($scope.attack_options, $scope.get_attack_options());
        result = $scope.attacker.chosen_weapon.attack($scope.defender, $scope.attack_options);
        result.attacker = $scope.attacker;
        result.defender = $scope.defender;
        result.type = 'attack';
        console.log(result);
        $scope.results.unshift(result);
        $("#attack_modal").modal("hide");
        return $scope.clear_attack();
      };
      $scope.remove_attack = function(result) {
        result.defender.heal(result.given_damage);
        return delete $scope.results.splice($scope.results.indexOf(result), 1);
      };
      $scope.save = function() {
        var blob;
        blob = new Blob([angular.toJson($scope.entities)], {
          type: "application/json;charset=utf-8"
        });
        return saveAs(blob, "rpg.json");
      };
      $scope.load = function() {
        $("#load_file").trigger("click");
      };
      $("#load_file").on("change", function() {
        var file, reader;
        file = this.files[0];
        if (!file) {
          return;
        }
        reader = new FileReader();
        reader.readAsText(file, "UTF-8");
        reader.onload = function(evt) {
          var group, j, len, results;
          results = JSON.parse(evt.target.result);
          for (j = 0, len = results.length; j < len; j++) {
            group = results[j];
            group.members = group.members.map(function(e) {
              return new Entity(e);
            });
          }
          return $scope.$apply(function(scope) {
            return scope.extend_entities(results);
          });
        };
        return reader.onerror = function(evt) {
          return console.error("error loading file");
        };
      });
      return $("#attack_modal").on("shown", function() {
        return setTimeout(function() {
          return $("#attack_modal input[name='custom_roll']").focus();
        }, 1);
      });
    }
  ]);

}).call(this);
