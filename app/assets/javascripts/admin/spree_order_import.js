//= require spree/backend
$(document).ready(
  function(){
    $('#csv_file').change(
      function(){
        if ($(this).val()) {
          $('input:submit').attr('disabled',false); 
        }
    }
  );
});
