data "archive_file" "layer" {
  type        = "zip"
  output_path = "../layer.zip"
  source_dir  = "../python"

  depends_on = [null_resource.python_dependencies]
}

resource "null_resource" "python_dependencies" {
  provisioner "local-exec" {
    command     = "pip3 install -r lambda/requirements.txt -t python"
    working_dir = ".."
  }
}
