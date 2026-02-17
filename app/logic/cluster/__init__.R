#' @export
box::use(
  app/logic/cluster/cluster[validate_inputs, run_clustering],
  app/logic/cluster/hopkins[compute_hopkins],
)
