# A demo shiny app of sparklinePlateMod
# run with shiny::runApp('demo.R')

library(shiny)

source('sparklinePlateMod.R')


server <- function(input, output) {

  microplate <- reactive({
    readRDS('demo_data.RDS')
  })

  selection <- callModule(slplate, id = 'test', data = microplate, nrow = 8, ncol = 12)

  output$selected <- renderPrint({
    selection()
  })


}

ui <- fluidPage(

  slplateUI('test'),
  verbatimTextOutput('selected')

)

shinyApp(ui, server)
