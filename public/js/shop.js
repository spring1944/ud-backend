$(document).on('ready', function () {
    $('span.unitdef').on('click', function (e) {
        var unitdef = $(this).data('unitdef');

        $('.unit-stats').addClass('hidden');
        var $unit = $('.' + unitdef);
        $unit.removeClass('hidden');
    });

    $('div.unit-stats button').click(function (e) {
        console.log($(this).data('unitdef'));
    });
});
