//= require admin/spree_backend
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
