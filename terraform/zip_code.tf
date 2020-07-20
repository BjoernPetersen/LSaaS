data "archive_file" "code" {
  type        = "zip"
  output_path = "../code.zip"
  source_dir  = "../lambda"
  excludes    = ["requirements.txt"]
}
