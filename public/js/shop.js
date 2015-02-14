$(document).on('ready', function () {
    var playerName = $('#player-name').text();

    $('span.unitdef').on('click', function (e) {
        var unitdef = $(this).data('unitdef');

        $('.unit-stats').addClass('hidden');
        var $unit = $('.' + unitdef);
        $unit.removeClass('hidden');
    });

    $('div.unit-stats button').click(function (e) {
        var unitdef = $(this).data('unitdef');
        var url = '/' + playerName + '/units/' + unitdef;
        $.ajax(url, {
            dataType: "json",
            type: "POST",
            success: function (data, textStatus, jqXHR) {
                if (data.error) {
                    if (data.error == 'not enough command') {
                        var $unitdef = $('div.' + unitdef);
                        $unitdef.append("<div class='temp-error'> you don't have enough money to buy a " + unitdef + " </div>");
                        setTimeout(function () {
                            $('div.temp-error').remove();
                        }, 5000);
                    }
                } else {
                    var money = data.balance;
                    var unit = data.unit;
                    unit.ammo = unit.ammo || '';
                    $('#cash').text(money);
                    var newUnitHtml = '<tr>';
                    newUnitHtml += '<td>' + unit.name + '</td>';
                    newUnitHtml += '<td>' + unit.health + '</td>';
                    newUnitHtml += '<td>' + unit.ammo + '</td>';
                    newUnitHtml += '<td>' + unit.experience + '</td>';
                    $('#army tr:last').after(newUnitHtml);
                }
            }
        });
    });
});
