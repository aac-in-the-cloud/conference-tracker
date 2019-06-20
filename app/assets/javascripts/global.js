var doc_lookup = function(doc_id, cell, success, error, stats) {
  if(cell == 'all') { return error(); }
  cell = cell.replace(/A17$/, '');
  var xhr = new XMLHttpRequest();
  xhr.onreadystatechange = function() {
    if(this.readyState == 4 && this.status == 200) {
      res = JSON.parse(this.responseText);
      success(res);
    } else if(this.readyState == 4) {
      error();
    }
  };
  var path = "/data/" + doc_id + "/" + cell;
  if(stats) { path = path + "?stats=1"; }
  xhr.open('GET', path, true);
  xhr.send();
}
window.doc_lookup = doc_lookup;