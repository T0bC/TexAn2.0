#' @export
box::use(
  app/logic/load_data/load_data[
    validate_file_extension,
    normalize_quote_char,
    read_data_file,
    validate_data,
  ],
  app/logic/load_data/example_data[
    list_examples,
    example_path,
    load_example,
  ],
)
