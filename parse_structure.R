# =============================================================================
# TexAn2.0 Codebase Structure Parser
#
# Standalone R script that extracts the complete module structure,
# dependencies, data flow, and reactive wiring from the TexAn2.0 codebase.
#
# Usage:
#   source("parse_structure.R")
#   structure <- parse_texan_structure()
#
# The returned list is designed for downstream visualization (e.g. C4,
# DiagrammeR, mermaid, etc.).
# =============================================================================


# =============================================================================
# 1. Box Module Parser
#    Extracts box::use() statements from R files.
#    Handles all observed patterns:
#      - Full module import:        app/logic/error_handling
#      - Selective import:          app/logic/pca/pca[validate_inputs, run_pca]
#      - CRAN package import:       shiny, bslib, ggplot2
#      - Multi-line box::use blocks
# =============================================================================

#' Parse all box::use() blocks from a single R file
#'
#' @param file_path Character, path to the R file
#' @return List of lists, each with:
#'   - module: Character, the module path (e.g. "app/logic/pca/pca")
#'   - selective: Character vector of imported names, or NULL if full import
#'   - type: "app" for internal modules, "cran" for external packages
parse_box_dependencies <- function(file_path) {
  if (!file.exists(file_path)) return(list())

  lines <- readLines(file_path, warn = FALSE)
  content <- paste(lines, collapse = "\n")

  # Find all box::use(...) blocks (may span multiple lines)
  box_blocks <- regmatches(
    content,
    gregexpr("box::use\\((?:[^()]*|\\([^()]*\\))*\\)", content, perl = TRUE)
  )[[1]]

  if (length(box_blocks) == 0) return(list())

  deps <- list()
  for (block in box_blocks) {
    # Remove the box::use( ... ) wrapper
    inner <- sub("^box::use\\(\\s*", "", block)
    inner <- sub("\\s*\\)\\s*$", "", inner)

    # Split on commas that are NOT inside brackets
    # Strategy: replace commas inside [...] with a placeholder, split, restore
    # First, extract bracket contents and replace
    protected <- inner
    bracket_contents <- regmatches(
      protected,
      gregexpr("\\[[^\\]]*\\]", protected, perl = TRUE)
    )[[1]]
    placeholders <- list()
    for (i in seq_along(bracket_contents)) {
      placeholder <- paste0("__BRACKET_", i, "__")
      placeholders[[placeholder]] <- bracket_contents[i]
      protected <- sub(
        bracket_contents[i], placeholder, protected, fixed = TRUE
      )
    }

    # Split on commas
    items <- strsplit(protected, ",")[[1]]
    items <- trimws(items)
    items <- items[nchar(items) > 0]

    for (item in items) {
      # Restore bracket contents
      restored <- item
      for (ph in names(placeholders)) {
        restored <- sub(ph, placeholders[[ph]], restored, fixed = TRUE)
      }

      # Remove trailing comments
      restored <- sub("#.*$", "", restored)
      restored <- trimws(restored)
      if (nchar(restored) == 0) next

      dep <- parse_single_box_item(restored)
      if (!is.null(dep)) {
        deps[[length(deps) + 1]] <- dep
      }
    }
  }

  deps
}


#' Parse a single item from a box::use() block
#'
#' @param item Character, e.g. "app/logic/pca/pca[validate_inputs, run_pca]"
#'   or "shiny" or "app/logic/error_handling"
#' @return List with module, selective, type
parse_single_box_item <- function(item) {
  item <- trimws(item)
  if (nchar(item) == 0) return(NULL)

  # Check for selective imports: module_path[func1, func2]
  bracket_match <- regmatches(
    item,
    regexec("^(.+?)\\[([^\\]]+)\\]$", item, perl = TRUE)
  )[[1]]

  if (length(bracket_match) == 3) {
    module_path <- trimws(bracket_match[2])
    selective_raw <- bracket_match[3]
    selective <- trimws(strsplit(selective_raw, ",")[[1]])
    selective <- selective[nchar(selective) > 0]
    dep_type <- if (grepl("^app/", module_path)) "app" else "cran"
    return(list(
      module = module_path,
      selective = selective,
      type = dep_type
    ))
  }

  # Full module import (no brackets)
  module_path <- trimws(item)
  dep_type <- if (grepl("^app/", module_path)) "app" else "cran"
  list(
    module = module_path,
    selective = NULL,
    type = dep_type
  )
}


# =============================================================================
# 2. Function Signature & Export Extractor
#    Scans R files for function definitions and @export tags.
# =============================================================================

#' Extract all function definitions from an R file
#'
#' @param file_path Character, path to the R file
#' @return List of lists, each with:
#'   - name: Function name
#'   - params: Character vector of parameter names
#'   - line: Line number of the definition
#'   - exported: Logical, TRUE if preceded by #' @export
#'   - roxygen: Character vector of roxygen comment lines (if any)
extract_functions <- function(file_path) {
  if (!file.exists(file_path)) return(list())

  lines <- readLines(file_path, warn = FALSE)
  fns <- list()

  # Pattern: name <- function(  OR  name = function(
  # The closing paren may be on the same line or a subsequent line.
  fn_start_pattern <- "^\\s*(\\w+)\\s*(<-|=)\\s*function\\s*\\("

  for (i in seq_along(lines)) {
    m <- regmatches(lines[i], regexec(fn_start_pattern, lines[i]))[[1]]
    if (length(m) >= 3) {
      fn_name <- m[2]

      # Collect the full signature (everything from 'function(' to the
      # matching closing paren, which may span multiple lines)
      sig_lines <- lines[i]
      paren_depth <- nchar(gsub("[^(]", "", lines[i])) -
        nchar(gsub("[^)]", "", lines[i]))
      j <- i
      while (paren_depth > 0 && j < length(lines)) {
        j <- j + 1
        sig_lines <- paste(sig_lines, lines[j])
        paren_depth <- paren_depth +
          nchar(gsub("[^(]", "", lines[j])) -
          nchar(gsub("[^)]", "", lines[j]))
      }

      # Extract params between function( ... )
      # Find the position of 'function(' and then extract to matching ')'
      fn_pos <- regexpr("function\\(", sig_lines)
      params_raw <- ""
      if (fn_pos > 0) {
        after_fn <- substring(sig_lines, fn_pos + 9)  # skip "function("
        # Walk to matching closing paren
        pdepth <- 1
        chars <- strsplit(after_fn, "")[[1]]
        end_pos <- 0
        for (ci in seq_along(chars)) {
          if (chars[ci] == "(") pdepth <- pdepth + 1
          if (chars[ci] == ")") pdepth <- pdepth - 1
          if (pdepth == 0) { end_pos <- ci - 1; break }
        }
        if (end_pos > 0) {
          params_raw <- substring(after_fn, 1, end_pos)
        }
      }

      params <- parse_function_params(params_raw)

      # Check for @export in preceding roxygen comments
      exported <- FALSE
      roxygen_lines <- character(0)
      k <- i - 1
      while (k >= 1 && grepl("^\\s*#'", lines[k])) {
        roxygen_lines <- c(lines[k], roxygen_lines)
        if (grepl("@export", lines[k])) exported <- TRUE
        k <- k - 1
      }

      fns[[length(fns) + 1]] <- list(
        name = fn_name,
        params = params,
        line = i,
        exported = exported,
        roxygen = roxygen_lines
      )
    }
  }

  fns
}


#' Parse function parameters from raw string
#'
#' @param raw Character, e.g. "id, input_data, data_version"
#' @return Character vector of parameter names (without defaults)
parse_function_params <- function(raw) {
  # Remove everything after closing paren
  raw <- sub("\\).*$", "", raw)
  raw <- trimws(raw)
  if (nchar(raw) == 0) return(character(0))

  # Split on commas, extract param names (before = default)
  parts <- strsplit(raw, ",")[[1]]
  params <- vapply(parts, function(p) {
    p <- trimws(p)
    # Remove default value
    name <- sub("\\s*=.*$", "", p)
    trimws(name)
  }, character(1), USE.NAMES = FALSE)

  params[nchar(params) > 0]
}


# =============================================================================
# 3. Reactive Dependency Tracker
#    Parses Shiny reactive patterns from view module server functions.
# =============================================================================

#' Extract reactive state variables from a view module server
#'
#' @param file_path Character, path to the R file
#' @return List with:
#'   - reactive_vals: Named list of reactiveVal declarations
#'   - observers: List of observeEvent/observe patterns
#'   - render_outputs: List of renderUI/renderPlot/etc patterns
#'   - return_value: Description of server return value (if any)
extract_reactive_state <- function(file_path) {
  if (!file.exists(file_path)) {
    return(list(
      reactive_vals = list(),
      observers = list(),
      render_outputs = list(),
      return_value = NULL
    ))
  }

  lines <- readLines(file_path, warn = FALSE)
  content <- paste(lines, collapse = "\n")

  # --- reactiveVal declarations ---
  rv_pattern <- "(\\w+)\\s*<-\\s*shiny\\$reactiveVal\\("
  rv_matches <- regmatches(content, gregexpr(rv_pattern, content, perl = TRUE))[[1]]
  reactive_vals <- vapply(rv_matches, function(m) {
    sub("\\s*<-.*$", "", m)
  }, character(1), USE.NAMES = FALSE)

  # --- reactive() declarations ---
  r_pattern <- "(\\w+)\\s*<-\\s*shiny\\$reactive\\("
  r_matches <- regmatches(content, gregexpr(r_pattern, content, perl = TRUE))[[1]]
  reactives <- vapply(r_matches, function(m) {
    sub("\\s*<-.*$", "", m)
  }, character(1), USE.NAMES = FALSE)

  # --- observeEvent triggers ---
  oe_pattern <- "shiny\\$observeEvent\\(([^,)]+)"
  oe_matches <- regmatches(
    content, gregexpr(oe_pattern, content, perl = TRUE)
  )[[1]]
  observers <- vapply(oe_matches, function(m) {
    trigger <- sub("^shiny\\$observeEvent\\(\\s*", "", m)
    trimws(trigger)
  }, character(1), USE.NAMES = FALSE)

  # --- render outputs ---
  render_pattern <- "output\\$(\\w+)\\s*<-\\s*\\w+"
  render_matches <- regmatches(
    content, gregexpr(render_pattern, content, perl = TRUE)
  )[[1]]
  render_outputs <- vapply(render_matches, function(m) {
    sub("\\s*<-.*$", "", sub("^output\\$", "", m))
  }, character(1), USE.NAMES = FALSE)

  # --- Server return value ---
  return_value <- extract_server_return(lines)

  list(
    reactive_vals = unique(reactive_vals),
    reactives = unique(reactives),
    observers = unique(observers),
    render_outputs = unique(render_outputs),
    return_value = return_value
  )
}


#' Extract the return value from a server function
#'
#' Looks for the last expression in a moduleServer block that is
#' a list(...) or a single reactive variable name.
#'
#' @param lines Character vector of file lines
#' @return List describing the return, or NULL
extract_server_return <- function(lines) {
  content <- paste(lines, collapse = "\n")

  # Look for a return list pattern at the end of moduleServer
  # Pattern: list(\n  key = shiny$reactive(...),\n  ...\n)
  # We find the LAST `list(` that contains reactive references
  # and appears to be the return value of the server

  # Strategy: find lines with "# Return" comments or the last list()
  # expression before the closing of moduleServer

  return_fields <- list()

  # Find "Return" comment lines as hints
  for (i in seq_along(lines)) {
    if (grepl("#.*[Rr]eturn", lines[i])) {
      # Look at next non-empty lines for the return expression
      j <- i + 1
      while (j <= length(lines) && grepl("^\\s*$", lines[j])) j <- j + 1

      if (j <= length(lines)) {
        # Check if it's a list() or a single variable
        if (grepl("^\\s*list\\(", lines[j])) {
          return_fields <- extract_return_list_fields(lines, j)
          break
        } else {
          # Single variable return
          var_name <- trimws(lines[j])
          var_name <- sub("\\s*$", "", var_name)
          if (nchar(var_name) > 0 && !grepl("[{}()]", var_name)) {
            return_fields <- list(list(
              key = var_name, type = "reactive"
            ))
            break
          }
        }
      }
    }
  }

  # Fallback: scan for last list() before }) })
  if (length(return_fields) == 0) {
    # Find lines that start a return-like list near end of file
    for (i in rev(seq_along(lines))) {
      line <- trimws(lines[i])
      if (grepl("^list\\(", line)) {
        return_fields <- extract_return_list_fields(lines, i)
        if (length(return_fields) > 0) break
      }
      # Stop scanning if we hit a function definition
      if (grepl("<-\\s*function", line)) break
    }
  }

  if (length(return_fields) == 0) return(NULL)
  return_fields
}


#' Extract named fields from a list() return expression
#'
#' @param lines Character vector of file lines
#' @param start_line Integer, line where list( begins
#' @return List of lists with key and type
extract_return_list_fields <- function(lines, start_line) {
  # Collect lines until matching closing paren
  paren_depth <- 0
  collected <- character(0)
  for (i in start_line:length(lines)) {
    collected <- c(collected, lines[i])
    paren_depth <- paren_depth +
      nchar(gsub("[^(]", "", lines[i])) -
      nchar(gsub("[^)]", "", lines[i]))
    if (paren_depth <= 0) break
  }

  block <- paste(collected, collapse = " ")

  # Extract key = value pairs
  # Pattern: key = shiny$reactive(...) or key = some_var
  pair_pattern <- "(\\w+)\\s*=\\s*"
  pair_matches <- gregexpr(pair_pattern, block, perl = TRUE)
  keys <- regmatches(block, pair_matches)[[1]]
  keys <- sub("\\s*=\\s*$", "", keys)
  keys <- trimws(keys)

  if (length(keys) == 0) {
    # Might be a single expression, not a named list
    inner <- sub("^\\s*list\\(\\s*", "", block)
    inner <- sub("\\s*\\)\\s*$", "", inner)
    inner <- trimws(inner)
    if (nchar(inner) > 0 && !grepl("=", inner)) {
      return(list(list(key = inner, type = "reactive")))
    }
    return(list())
  }

  lapply(keys, function(k) {
    list(key = k, type = "reactive")
  })
}


# =============================================================================
# 4. Data Flow Analyzer
#    Parses main.R to extract the reactive data pipeline:
#    which modules receive which data, and what they return.
# =============================================================================

#' Analyze the data flow from main.R
#'
#' @param main_file Character, path to app/main.R
#' @return List with:
#'   - modules: Named list of modules with their inputs and outputs
#'   - pipeline: List describing the data flow chain
#'   - cross_module: List of cross-module dependencies
analyze_data_flow <- function(main_file) {
  if (!file.exists(main_file)) {
    return(list(modules = list(), pipeline = list(), cross_module = list()))
  }

  lines <- readLines(main_file, warn = FALSE)
  content <- paste(lines, collapse = "\n")

  modules <- list()
  pipeline <- list()
  cross_module <- list()

  # --- Extract module server calls ---
  # Patterns (may span multiple lines):
  #   result <- module$server("id", arg1 = val1, ...)
  #   module$server("id", arg1 = val1, ...)
  # Strategy: find lines containing $server(, collect the full call,
  # then parse the flattened string.
  # We also track which lines we've already processed to avoid duplicates.

  processed_lines <- integer(0)

  for (i in seq_along(lines)) {
    if (i %in% processed_lines) next
    line <- trimws(lines[i])

    # Skip lines that don't contain a $server( call
    if (!grepl("\\$server\\(", line)) next

    # Collect the full multi-line call (spaces from indentation preserved)
    full_call <- collect_call_lines(lines, i)
    # Mark all lines in this call as processed to avoid duplicates
    call_end <- i
    pd <- 0
    for (k in i:length(lines)) {
      pd <- pd +
        nchar(gsub("[^(]", "", lines[k])) -
        nchar(gsub("[^)]", "", lines[k]))
      call_end <- k
      if (pd <= 0) break
    }
    processed_lines <- c(processed_lines, i:call_end)

    # Trim the full_call for regex matching (remove leading whitespace)
    full_call_trimmed <- trimws(full_call)

    # Try: var <- module$server("id", ...)
    m <- regmatches(
      full_call_trimmed,
      regexec(
        "(\\w+)\\s*<-\\s*(\\w+)\\$server\\(\\s*\"([^\"]+)\"",
        full_call_trimmed
      )
    )[[1]]

    if (length(m) >= 4) {
      result_var <- m[2]
      module_name <- m[3]
      module_id <- m[4]
      args <- extract_server_call_args(full_call_trimmed)

      modules[[module_name]] <- list(
        id = module_id,
        result_var = result_var,
        inputs = args,
        line = i
      )
      next
    }

    # Try: module$server("id", ...) without assignment
    m2 <- regmatches(
      full_call_trimmed,
      regexec("(\\w+)\\$server\\(\\s*\"([^\"]+)\"", full_call_trimmed)
    )[[1]]

    if (length(m2) >= 3) {
      module_name <- m2[2]
      module_id <- m2[3]
      args <- extract_server_call_args(full_call_trimmed)

      modules[[module_name]] <- list(
        id = module_id,
        result_var = NULL,
        inputs = args,
        line = i
      )
    }
  }

  # --- Parse intermediate reactive variables from main.R ---
  # These are local reactives in the server that transform data between
  # module calls, e.g.:
  #   plotting_data <- shiny$reactive({ median_result() %||% load_data_result$data() })
  #   processed_plotting_data <- shiny$reactive({ plotting_result$processed_data() ... })
  intermediates <- parse_intermediate_reactives(lines, modules)

  # --- Build pipeline from data dependencies ---
  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    for (arg in mod$inputs) {
      if (is.null(arg$name)) next
      # Resolve the source: direct module result or intermediate
      source <- resolve_data_source(arg$value, modules, intermediates)
      if (!is.null(source)) {
        cross_module[[length(cross_module) + 1]] <- list(
          from_module = source$module,
          to_module = mod_name,
          data_key = arg$name,
          expression = arg$value,
          via_intermediate = source$via
        )
      }
    }
  }

  # --- Build ordered pipeline ---
  pipeline <- build_pipeline_order(modules, cross_module)

  list(
    modules = modules,
    pipeline = pipeline,
    cross_module = cross_module,
    intermediates = intermediates
  )
}


#' Parse intermediate reactive variables from main.R
#'
#' Finds patterns like:
#'   plotting_data <- shiny$reactive({ median_result() %||% load_data_result$data() })
#'   processed_plotting_data <- shiny$reactive({ plotting_result$processed_data() ... })
#' and traces which module results they reference.
#'
#' @param lines Character vector of main.R lines
#' @param modules Named list of parsed module server calls
#' @return Named list: variable_name -> list(sources = character vector of module names)
parse_intermediate_reactives <- function(lines, modules) {
  intermediates <- list()

  for (i in seq_along(lines)) {
    line <- trimws(lines[i])

    # Match: var_name <- shiny$reactive({  or  var_name <- shiny$reactiveVal(
    m <- regmatches(
      line,
      regexec("^(\\w+)\\s*<-\\s*shiny\\$(reactive|reactiveVal)\\(", line)
    )[[1]]

    if (length(m) < 3) next

    var_name <- m[2]
    # Skip if this is inside a module (we only want top-level main.R reactives)
    # Also skip if it matches a known module result_var
    is_module_var <- any(vapply(modules, function(mod) {
      identical(mod$result_var, var_name)
    }, logical(1)))
    if (is_module_var) next

    # Collect the full reactive body
    body <- collect_call_lines(lines, i)

    # Find all module result references in the body
    source_modules <- character(0)
    for (mod_name in names(modules)) {
      mod <- modules[[mod_name]]
      if (!is.null(mod$result_var)) {
        # Check if this intermediate references the module's result var
        if (grepl(mod$result_var, body, fixed = TRUE)) {
          source_modules <- c(source_modules, mod_name)
        }
      }
    }

    # Also check if it references other intermediates (will resolve later)
    intermediates[[var_name]] <- list(
      sources = unique(source_modules),
      body = body,
      line = i
    )
  }

  # Second pass: resolve intermediates that reference other intermediates
  for (var_name in names(intermediates)) {
    inter <- intermediates[[var_name]]
    for (other_name in names(intermediates)) {
      if (other_name == var_name) next
      if (grepl(other_name, inter$body, fixed = TRUE)) {
        intermediates[[var_name]]$sources <- unique(c(
          inter$sources,
          intermediates[[other_name]]$sources
        ))
      }
    }
  }

  intermediates
}


#' Resolve a data source expression to its originating module
#'
#' @param expr Character, the argument value expression
#' @param modules Named list of parsed module server calls
#' @param intermediates Named list of intermediate reactives
#' @return List with module (character) and via (character or NULL), or NULL
resolve_data_source <- function(expr, modules, intermediates) {
  # 1. Direct module result reference: load_data_result$data
  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    if (!is.null(mod$result_var) &&
        grepl(mod$result_var, expr, fixed = TRUE)) {
      return(list(module = mod_name, via = NULL))
    }
  }

  # 2. Intermediate reactive reference: plotting_data, processed_plotting_data
  for (inter_name in names(intermediates)) {
    if (grepl(inter_name, expr, fixed = TRUE)) {
      sources <- intermediates[[inter_name]]$sources
      if (length(sources) > 0) {
        return(list(module = sources, via = inter_name))
      }
    }
  }

  # 3. Direct reference to a known reactive (e.g. pca_result, lda_result)
  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    if (!is.null(mod$result_var) && grepl(mod$result_var, expr, fixed = TRUE)) {
      return(list(module = mod_name, via = NULL))
    }
  }

  NULL
}


#' Collect all lines of a function call that may span multiple lines
#'
#' @param lines Character vector
#' @param start_line Integer
#' @return Character, the full call as a single string
collect_call_lines <- function(lines, start_line) {
  collected <- character(0)
  paren_depth <- 0
  for (i in start_line:length(lines)) {
    collected <- c(collected, lines[i])
    paren_depth <- paren_depth +
      nchar(gsub("[^(]", "", lines[i])) -
      nchar(gsub("[^)]", "", lines[i]))
    if (paren_depth <= 0) break
  }
  paste(collected, collapse = " ")
}


#' Extract named arguments from a server call
#'
#' @param call_text Character, full call as single string
#' @return List of lists with name and value
extract_server_call_args <- function(call_text) {
  # Remove the function call prefix: module$server("id",
  inner <- sub("^.*\\$server\\(\\s*\"[^\"]+\"\\s*,?\\s*", "", call_text)
  inner <- sub("\\)\\s*$", "", inner)
  inner <- trimws(inner)

  if (nchar(inner) == 0) return(list())

  # Split on commas (careful with nested expressions)
  args <- split_top_level_commas(inner)

  lapply(args, function(a) {
    a <- trimws(a)
    if (grepl("=", a)) {
      parts <- strsplit(a, "=", fixed = TRUE)[[1]]
      list(
        name = trimws(parts[1]),
        value = trimws(paste(parts[-1], collapse = "="))
      )
    } else {
      list(name = NULL, value = a)
    }
  })
}


#' Split a string on top-level commas (not inside parens)
#'
#' @param s Character
#' @return Character vector
split_top_level_commas <- function(s) {
  parts <- character(0)
  current <- ""
  depth <- 0
  chars <- strsplit(s, "")[[1]]

  for (ch in chars) {
    if (ch == "(" || ch == "{") {
      depth <- depth + 1
      current <- paste0(current, ch)
    } else if (ch == ")" || ch == "}") {
      depth <- depth - 1
      current <- paste0(current, ch)
    } else if (ch == "," && depth == 0) {
      parts <- c(parts, current)
      current <- ""
    } else {
      current <- paste0(current, ch)
    }
  }
  if (nchar(trimws(current)) > 0) {
    parts <- c(parts, current)
  }
  parts
}


#' Find which module provides a given variable
#'
#' @param expr Character, e.g. "load_data_result$data"
#' @param modules Named list of modules
#' @return Character, module name or "unknown"
find_source_module <- function(expr, modules) {
  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    if (!is.null(mod$result_var) && grepl(mod$result_var, expr, fixed = TRUE)) {
      return(mod_name)
    }
  }
  "unknown"
}


#' Build a topologically ordered pipeline
#'
#' @param modules Named list of modules
#' @param cross_module List of cross-module dependencies
#' @return Character vector of module names in pipeline order
build_pipeline_order <- function(modules, cross_module) {
  # Simple topological sort based on dependencies
  mod_names <- names(modules)
  deps <- list()
  for (m in mod_names) deps[[m]] <- character(0)

  for (xm in cross_module) {
    # from_module may be a character vector (multiple sources via intermediates)
    from_mods <- xm$from_module
    if (is.null(from_mods)) from_mods <- character(0)
    from_mods <- from_mods[from_mods != "unknown"]
    to_mod <- xm$to_module
    if (length(from_mods) > 0 && length(to_mod) == 1 && to_mod %in% mod_names) {
      deps[[to_mod]] <- unique(c(deps[[to_mod]], from_mods))
    }
  }

  ordered <- character(0)
  remaining <- mod_names

  while (length(remaining) > 0) {
    # Find modules with all dependencies satisfied
    ready <- vapply(remaining, function(m) {
      all(deps[[m]] %in% ordered)
    }, logical(1))

    if (!any(ready)) {
      # Circular dependency or missing module — add remaining
      ordered <- c(ordered, remaining)
      break
    }

    batch <- remaining[ready]
    ordered <- c(ordered, batch)
    remaining <- remaining[!ready]
  }

  ordered
}


# =============================================================================
# 5. Module Structure Mapper
#    Maps the logic/ and view/ directory structure into a unified
#    module hierarchy.
# =============================================================================

#' Map the complete module structure
#'
#' @param base_path Character, path to the app/ directory
#' @return List of module descriptors
map_module_structure <- function(base_path) {
  logic_path <- file.path(base_path, "logic")
  view_path <- file.path(base_path, "view")

  # Discover top-level modules (directories under logic/ and view/)
  logic_dirs <- list.dirs(logic_path, recursive = FALSE, full.names = FALSE)
  view_dirs <- list.dirs(view_path, recursive = FALSE, full.names = FALSE)
  # Also include single-file modules at logic/ and view/ root
  logic_root_files <- list.files(
    logic_path, pattern = "\\.R$", full.names = FALSE
  )
  logic_root_files <- logic_root_files[logic_root_files != "__init__.R"]
  view_root_files <- list.files(
    view_path, pattern = "\\.R$", full.names = FALSE
  )
  view_root_files <- view_root_files[view_root_files != "__init__.R"]

  all_module_names <- unique(c(
    logic_dirs, view_dirs,
    sub("\\.R$", "", logic_root_files),
    sub("\\.R$", "", view_root_files)
  ))

  modules <- list()
  for (mod_name in all_module_names) {
    mod <- parse_single_module(mod_name, logic_path, view_path)
    modules[[mod_name]] <- mod
  }

  modules
}


#' Parse a single module (logic + view)
#'
#' @param mod_name Character, module name (e.g. "pca", "load_data")
#' @param logic_path Character, path to logic/ directory
#' @param view_path Character, path to view/ directory
#' @return List describing the module
parse_single_module <- function(mod_name, logic_path, view_path) {
  # Logic files
  logic_dir <- file.path(logic_path, mod_name)
  logic_single <- file.path(logic_path, paste0(mod_name, ".R"))
  logic_files <- character(0)

  if (dir.exists(logic_dir)) {
    logic_files <- list.files(logic_dir, pattern = "\\.R$", full.names = TRUE)
  } else if (file.exists(logic_single)) {
    logic_files <- logic_single
  }

  # View files
  view_dir <- file.path(view_path, mod_name)
  view_single <- file.path(view_path, paste0(mod_name, ".R"))
  view_files <- character(0)

  if (dir.exists(view_dir)) {
    view_files <- list.files(view_dir, pattern = "\\.R$", full.names = TRUE)
  } else if (file.exists(view_single)) {
    view_files <- view_single
  }

  # Parse each file for dependencies and functions
  logic_info <- lapply(logic_files, function(f) {
    list(
      file = f,
      filename = basename(f),
      dependencies = parse_box_dependencies(f),
      functions = extract_functions(f)
    )
  })

  view_info <- lapply(view_files, function(f) {
    list(
      file = f,
      filename = basename(f),
      dependencies = parse_box_dependencies(f),
      functions = extract_functions(f),
      reactive_state = extract_reactive_state(f)
    )
  })

  # Aggregate exports across all files
  all_exports <- character(0)
  for (info in c(logic_info, view_info)) {
    for (fn in info$functions) {
      if (fn$exported) {
        all_exports <- c(all_exports, fn$name)
      }
    }
  }

  # Aggregate all dependencies
  all_app_deps <- character(0)
  all_cran_deps <- character(0)
  for (info in c(logic_info, view_info)) {
    for (dep in info$dependencies) {
      if (dep$type == "app") {
        all_app_deps <- c(all_app_deps, dep$module)
      } else {
        all_cran_deps <- c(all_cran_deps, dep$module)
      }
    }
  }

  # Determine if this has a UI/server pattern (Shiny module)
  has_ui <- "ui" %in% all_exports
  has_server <- "server" %in% all_exports

  # Find the main view file's server return value
  server_return <- NULL
  for (vi in view_info) {
    if (!is.null(vi$reactive_state$return_value)) {
      server_return <- vi$reactive_state$return_value
      break
    }
  }

  list(
    name = mod_name,
    type = if (has_ui && has_server) {
      "shiny_module"
    } else if (length(logic_files) > 0 && length(view_files) == 0) {
      "logic_only"
    } else if (length(view_files) > 0 && length(logic_files) == 0) {
      "view_only"
    } else {
      "mixed"
    },
    logic_files = logic_info,
    view_files = view_info,
    exports = unique(all_exports),
    app_dependencies = unique(all_app_deps),
    cran_dependencies = unique(all_cran_deps),
    is_shiny_module = has_ui && has_server,
    server_return = server_return
  )
}


# =============================================================================
# 6. Main Entry Point
# =============================================================================

#' Parse the complete TexAn2.0 codebase structure
#'
#' @param base_path Character, path to the app/ directory
#'   (default: "app" relative to project root)
#' @return Nested list with:
#'   - modules: Detailed module descriptors
#'   - data_flow: Data pipeline and cross-module dependencies
#'   - main_app: Parsed main.R (box deps, functions, reactive state)
#'   - architecture: High-level summary for visualization
parse_texan_structure <- function(base_path = "app") {
  main_file <- file.path(base_path, "main.R")

  # --- Module structure ---
  modules <- map_module_structure(base_path)

  # --- Data flow from main.R ---
  data_flow <- analyze_data_flow(main_file)

  # --- Main app file analysis ---
  main_app <- list(
    dependencies = parse_box_dependencies(main_file),
    functions = extract_functions(main_file),
    reactive_state = extract_reactive_state(main_file)
  )

  # --- Architecture summary ---
  architecture <- build_architecture_summary(modules, data_flow, main_app)

  list(
    modules = modules,
    data_flow = data_flow,
    main_app = main_app,
    architecture = architecture
  )
}


#' Build a high-level architecture summary for visualization
#'
#' @param modules Named list of module descriptors
#' @param data_flow Data flow analysis result
#' @param main_app Main app analysis result
#' @return List with:
#'   - shiny_modules: Character vector of Shiny module names
#'   - logic_modules: Character vector of logic-only module names
#'   - shared_modules: Character vector of shared/utility module names
#'   - dependency_edges: Data frame of from -> to edges
#'   - data_flow_edges: Data frame of data flow edges with labels
#'   - module_summary: Data frame with module name, type, n_files, n_exports
build_architecture_summary <- function(modules, data_flow, main_app) {
  # Categorize modules
  shiny_modules <- character(0)
  logic_modules <- character(0)
  shared_modules <- character(0)

  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    if (mod$is_shiny_module) {
      shiny_modules <- c(shiny_modules, mod_name)
    } else if (mod$type == "logic_only") {
      # Check if used by multiple modules (shared utility)
      users <- sum(vapply(modules, function(m) {
        any(grepl(mod_name, m$app_dependencies, fixed = TRUE))
      }, logical(1)))
      if (users > 1) {
        shared_modules <- c(shared_modules, mod_name)
      } else {
        logic_modules <- c(logic_modules, mod_name)
      }
    } else {
      logic_modules <- c(logic_modules, mod_name)
    }
  }

  # Build dependency edges
  dep_edges <- data.frame(
    from = character(0), to = character(0),
    type = character(0),
    stringsAsFactors = FALSE
  )

  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    for (dep_path in mod$app_dependencies) {
      # Extract the top-level module name from the dependency path
      dep_parts <- strsplit(dep_path, "/")[[1]]
      # app/logic/MODULE/... or app/view/MODULE/...
      if (length(dep_parts) >= 3) {
        dep_module <- dep_parts[3]
        if (dep_module != mod_name) {
          dep_type <- dep_parts[2]  # "logic" or "view"
          dep_edges <- rbind(dep_edges, data.frame(
            from = mod_name, to = dep_module, type = dep_type,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
  dep_edges <- unique(dep_edges)

  # Build data flow edges from main.R cross-module analysis
  flow_edges <- data.frame(
    from = character(0), to = character(0),
    label = character(0), expression = character(0),
    via = character(0),
    stringsAsFactors = FALSE
  )

  for (xm in data_flow$cross_module) {
    # from_module may be a character vector (multiple sources)
    from_mods <- xm$from_module
    if (is.null(from_mods) || length(from_mods) == 0) {
      from_mods <- "unknown"
    }
    for (fm in from_mods) {
      flow_edges <- rbind(flow_edges, data.frame(
        from = fm,
        to = xm$to_module,
        label = xm$data_key %||% "",
        expression = xm$expression %||% "",
        via = xm$via_intermediate %||% "",
        stringsAsFactors = FALSE
      ))
    }
  }
  flow_edges <- unique(flow_edges)

  # Module summary table
  mod_summary <- data.frame(
    name = character(0),
    type = character(0),
    n_logic_files = integer(0),
    n_view_files = integer(0),
    n_exports = integer(0),
    n_app_deps = integer(0),
    n_cran_deps = integer(0),
    is_shiny_module = logical(0),
    stringsAsFactors = FALSE
  )

  for (mod_name in names(modules)) {
    mod <- modules[[mod_name]]
    mod_summary <- rbind(mod_summary, data.frame(
      name = mod_name,
      type = mod$type,
      n_logic_files = length(mod$logic_files),
      n_view_files = length(mod$view_files),
      n_exports = length(mod$exports),
      n_app_deps = length(mod$app_dependencies),
      n_cran_deps = length(mod$cran_dependencies),
      is_shiny_module = mod$is_shiny_module,
      stringsAsFactors = FALSE
    ))
  }

  list(
    shiny_modules = shiny_modules,
    logic_modules = logic_modules,
    shared_modules = shared_modules,
    dependency_edges = dep_edges,
    data_flow_edges = flow_edges,
    module_summary = mod_summary,
    pipeline_order = data_flow$pipeline
  )
}


# =============================================================================
# 7. Utility: null-coalescing operator (if not already available)
# =============================================================================
`%||%` <- function(lhs, rhs) if (is.null(lhs)) rhs else lhs


# =============================================================================
# 8. Structured File Output
#    Writes the parsed structure to a JSON file for downstream consumption.
# =============================================================================

#' Write the parsed structure to a JSON file
#'
#' @param structure Result from parse_texan_structure()
#' @param output_path Character, path to write the JSON file
#'   (default: "codebase_structure.json" next to this script)
write_structure_json <- function(structure, output_path = "codebase_structure.json") {
  # Convert the nested structure to a JSON-friendly format
  result <- list(
    architecture = list(
      shiny_modules = structure$architecture$shiny_modules,
      logic_modules = structure$architecture$logic_modules,
      shared_modules = structure$architecture$shared_modules,
      pipeline_order = structure$architecture$pipeline_order,
      module_summary = df_to_records(structure$architecture$module_summary),
      dependency_edges = df_to_records(structure$architecture$dependency_edges),
      data_flow_edges = df_to_records(structure$architecture$data_flow_edges)
    ),
    data_flow = list(
      modules = lapply(structure$data_flow$modules, function(mod) {
        list(
          id = mod$id,
          result_var = mod$result_var,
          inputs = lapply(mod$inputs, function(a) {
            list(name = a$name %||% "", value = a$value %||% "")
          }),
          line = mod$line
        )
      }),
      intermediates = lapply(structure$data_flow$intermediates, function(inter) {
        list(sources = inter$sources, line = inter$line)
      })
    ),
    modules = lapply(structure$modules, function(mod) {
      list(
        name = mod$name,
        type = mod$type,
        is_shiny_module = mod$is_shiny_module,
        exports = mod$exports,
        app_dependencies = mod$app_dependencies,
        cran_dependencies = mod$cran_dependencies,
        server_return = simplify_return(mod$server_return),
        logic_files = lapply(mod$logic_files, function(f) {
          list(
            filename = f$filename,
            functions = lapply(f$functions, function(fn) {
              list(
                name = fn$name,
                params = fn$params,
                exported = fn$exported,
                line = fn$line
              )
            }),
            dependencies = lapply(f$dependencies, function(dep) {
              list(
                module = dep$module,
                selective = dep$selective,
                type = dep$type
              )
            })
          )
        }),
        view_files = lapply(mod$view_files, function(f) {
          list(
            filename = f$filename,
            functions = lapply(f$functions, function(fn) {
              list(
                name = fn$name,
                params = fn$params,
                exported = fn$exported,
                line = fn$line
              )
            }),
            dependencies = lapply(f$dependencies, function(dep) {
              list(
                module = dep$module,
                selective = dep$selective,
                type = dep$type
              )
            }),
            reactive_state = list(
              reactive_vals = f$reactive_state$reactive_vals,
              reactives = f$reactive_state$reactives,
              observers = f$reactive_state$observers,
              render_outputs = f$reactive_state$render_outputs,
              return_value = simplify_return(f$reactive_state$return_value)
            )
          )
        })
      )
    })
  )

  json <- to_json(result, indent = 2)
  writeLines(json, output_path, useBytes = TRUE)
  cat("Structure written to:", normalizePath(output_path), "\n")
  invisible(output_path)
}


#' Convert a data.frame to a list of row-records (for JSON)
df_to_records <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(list())
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}


#' Simplify server return value for JSON
simplify_return <- function(ret) {
  if (is.null(ret)) return(NULL)
  lapply(ret, function(r) {
    list(key = r$key %||% "", type = r$type %||% "")
  })
}


# =============================================================================
# 9. Minimal JSON serializer (no external dependencies)
# =============================================================================

#' Convert an R object to a JSON string (no dependencies)
#'
#' @param x R object (list, vector, data.frame, scalar)
#' @param indent Integer, spaces per indent level (0 = compact)
#' @return Character, JSON string
to_json <- function(x, indent = 0, .level = 0) {
  pad <- if (indent > 0) strrep(" ", indent * .level) else ""
  pad1 <- if (indent > 0) strrep(" ", indent * (.level + 1)) else ""
  nl <- if (indent > 0) "\n" else ""

  if (is.null(x)) return("null")
  if (is.logical(x) && length(x) == 1) return(if (x) "true" else "false")
  if (is.atomic(x) && length(x) == 1 && !is.list(x)) {
    if (is.na(x)) return("null")
    if (is.numeric(x)) return(as.character(x))
    return(json_escape(as.character(x)))
  }

  # Named list -> JSON object
  if (is.list(x) && !is.null(names(x))) {
    if (length(x) == 0) return("{}")
    entries <- vapply(names(x), function(k) {
      val <- to_json(x[[k]], indent, .level + 1)
      paste0(pad1, json_escape(k), ": ", val)
    }, character(1))
    return(paste0("{", nl, paste(entries, collapse = paste0(",", nl)), nl, pad, "}"))
  }

  # Unnamed list or vector -> JSON array
  if (is.list(x)) {
    if (length(x) == 0) return("[]")
    entries <- vapply(seq_along(x), function(i) {
      paste0(pad1, to_json(x[[i]], indent, .level + 1))
    }, character(1))
    return(paste0("[", nl, paste(entries, collapse = paste0(",", nl)), nl, pad, "]"))
  }

  # Atomic vector with length > 1 -> JSON array
  if (is.atomic(x) && length(x) > 1) {
    entries <- vapply(x, function(v) {
      to_json(v, indent = 0, .level = 0)
    }, character(1))
    return(paste0("[", paste(entries, collapse = ", "), "]"))
  }

  # Fallback
  json_escape(as.character(x))
}


#' Escape a string for JSON
json_escape <- function(s) {
  s <- gsub("\\\\", "\\\\\\\\", s)
  s <- gsub("\"", "\\\\\"", s)
  s <- gsub("\n", "\\\\n", s)
  s <- gsub("\r", "\\\\r", s)
  s <- gsub("\t", "\\\\t", s)
  paste0("\"", s, "\"")
}


# =============================================================================
# 10. Auto-run: parse and write to file
# =============================================================================
if (interactive() || identical(sys.nframe(), 0L)) {
  structure <- parse_texan_structure()
  write_structure_json(structure, "codebase_structure.json")
}
