library(magrittr)
library(dplyr)
library(tidyr)
library(DT)

slplate_formatData <- function(df, nrow, ncol) {

  # check variables
  stopifnot('Well' %in% names(df))
  stopifnot('Y' %in% names(df))

  if(! 'X' %in% names(df)) {
    df %<>%
      group_by(Well) %>%
      mutate(X = seq_along(Y))
  }


  # build sparkline tag-options
  ops <- list(
    type='line',
    defaultPixelsPerValue=1,
    spotColor='',
    chartRangeMin=min(df$Y),
    chartRangeMax=max(df$Y)
  )

  vals <- sapply(ops, function(x) {
    if(is.numeric(x)) {
      return(x)
    } else {
      return(paste0('"', x, '"'))
    }
  })

  tag_attrs <- paste('spark', names(ops), '=', vals, sep = '', collapse = ' ')


  # format data
  row_names <- LETTERS[1:nrow]
  col_names <- as.character(1:ncol)
  full_plate <- expand.grid(Row = row_names, Col = col_names) %>%
    unite(Well, Row, Col, sep = '')

  df %>%
    arrange(X) %>%
    group_by(Well) %>%
    summarise(Values = paste(X, Y, sep = ':', collapse = ',')) %>%
    right_join(full_plate, by = 'Well') %>%
    mutate(Well = factor(Well, levels = full_plate$Well)) %>%
    arrange(Well) %>%
    use_series(Values) %>%
    paste('<span ', 'class=spark ', tag_attrs, ' values=', ., '></span>') %>%
    matrix(nrow = nrow) %>%
    set_rownames(row_names) %>%
    set_colnames(col_names)

}

slplate_buildDT <- function(data) {

  dt <- datatable(data, escape = F,
                  selection = 'none',
                  extensions = 'Select',
                  class = 'cell-border compact',
                  callback = JS(
                    "table.on( 'click.dt', 'tbody td', function (e) {", # react on click event
                    "var type = table.select.items();", # get the items setting of Select extension
                    "var idx = table[type + 's']({selected: true}).indexes().toArray();", # get the index of selected items
                    "var DT_id = table.table().container().parentNode.id;", # get the output id of DT
                    "Shiny.onInputChange(DT_id + '_selected', idx);", # send the index to input$outputid_selected
                    "})",
                    "Shiny.addCustomMessageHandler('slplate_clear_selected_handler', function(DT_id){",
                    "var type = table.select.items();",
                    "table[type + 's']({selected: true}).deselect();",
                    "Shiny.onInputChange(DT_id + '_selected', null);",
                    "})"
                  ),
                  options = list(
                    paging = F,
                    ordering = F,
                    dom = 'rt',
                    select = list(items = 'cell', style = 'os'),
                    columnDefs = list(
                      list(
                        targets = '_all',
                        className = 'dt-center'
                      )
                    ),
                    fnDrawCallback = JS("
                      function (oSettings) {
                        $('.spark:not(:has(canvas))').sparkline('html', {
                          enableTagOptions: true
                        });
                      }
                    ")
                  )
  )
  dt$dependencies <- append(dt$dependencies,
                            htmlwidgets:::getDependency("sparkline"))

  return(dt)

}

slplateUI <- function(id, width = 'auto', height = 'auto'){
  ns <- NS(id)
  tagList(
    tags$head(tags$style(HTML(".jqstooltip{box-sizing: content-box;}"))),
    DT::dataTableOutput(ns('dt'), width = width, height = height)
  )
}

slplate <- function(input, output, session, data,
                    nrow = 8, ncol = 12) {

  output$dt <- DT::renderDataTable({
    validate(need(data(), ''))
    data() %>%
      slplate_formatData(nrow, ncol) %>%
      slplate_buildDT()
  })

  selected_data <- reactive({
    selected <- input$dt_selected
    if(is.null(selected) || length(selected) == 0) return(NULL)

    isolate({

      selected %<>%
        matrix(ncol = 3, byrow = T) %>%
        set_colnames(c('row', 'column', 'columnVisible')) %>%
        as.data.frame() %>%
        mutate(row = row + 1)

      wells <- paste0(LETTERS[selected$row], selected$column)

      out <- data() %>%
        filter(Well %in% wells)

      if(nrow(out) == 0) return(NULL)

      return(out)
    })

  })

  return(selected_data)

}
