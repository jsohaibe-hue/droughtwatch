#' Launch Interactive Shiny Dashboard
#'
#' Launches a Shiny web application for interactive drought monitoring,
#' allowing users to upload data, visualise indices, select regions, view
#' alerts, and download reports.
#'
#' @param data Tibble or NULL. Pre-loaded climate data. If \code{NULL}, the
#'   dashboard allows the user to upload a CSV file.
#' @param region Character. Default region name. Default: \code{"Study area"}.
#' @param launch_browser Logical. Open in web browser. Default: \code{TRUE}.
#' @param port Integer. Port number. Default: \code{NULL} (auto).
#'
#' @return Invisibly returns the Shiny app object.
#'
#' @examples
#' \dontrun{
#' data(morocco_climate)
#' shiny_dashboard(data = morocco_climate, region = "Beni Mellal-Khenifra")
#' }
#'
#' @export
shiny_dashboard <- function(data = NULL, region = "Study area",
                             launch_browser = TRUE, port = NULL) {

  for (pkg in c("shiny", "shinydashboard", "plotly")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Package '", pkg, "' required. Install with: install.packages('", pkg, "')")
    }
  }

  # Pre-process data if provided
  initial_spi <- if (!is.null(data)) {
    tryCatch(calc_spi(data, scales = c(1, 3, 6)), error = function(e) NULL)
  } else NULL

  # ---- UI ----
  ui <- shinydashboard::dashboardPage(
    skin = "blue",

    shinydashboard::dashboardHeader(
      title = shiny::tags$span(
        shiny::icon("cloud-rain"), " droughtwatch"
      )
    ),

    shinydashboard::dashboardSidebar(
      shinydashboard::sidebarMenu(
        shinydashboard::menuItem("Overview",     tabName = "overview",  icon = shiny::icon("chart-line")),
        shinydashboard::menuItem("Indices",      tabName = "indices",   icon = shiny::icon("water")),
        shinydashboard::menuItem("Alerts",       tabName = "alerts",    icon = shiny::icon("bell")),
        shinydashboard::menuItem("Forecast",     tabName = "forecast",  icon = shiny::icon("forward")),
        shinydashboard::menuItem("Download",     tabName = "download",  icon = shiny::icon("download"))
      ),
      shiny::hr(),
      shiny::tags$div(
        style = "padding: 10px;",
        shiny::fileInput("upload_file", "Upload Climate CSV",
                          accept = c(".csv"), buttonLabel = "Browse"),
        shiny::selectInput("scale_choice", "SPI Scale (months)",
                            choices = c("1", "3", "6"), selected = "3"),
        shiny::selectInput("index_type", "Index",
                            choices = c("SPI", "SPEI"), selected = "SPI"),
        shiny::textInput("region_name", "Region", value = region),
        shiny::actionButton("compute_btn", "Compute Indices",
                             class = "btn-primary btn-block",
                             icon  = shiny::icon("play"))
      )
    ),

    shinydashboard::dashboardBody(
      shinydashboard::tabItems(

        # --- Overview tab ---
        shinydashboard::tabItem("overview",
          shiny::fluidRow(
            shinydashboard::valueBoxOutput("vbox_alerts",    width = 4),
            shinydashboard::valueBoxOutput("vbox_episodes",  width = 4),
            shinydashboard::valueBoxOutput("vbox_latest",    width = 4)
          ),
          shiny::fluidRow(
            shinydashboard::box(
              title = "Drought Index Time Series", width = 12, status = "primary",
              plotly::plotlyOutput("ts_plot", height = "350px")
            )
          )
        ),

        # --- Indices tab ---
        shinydashboard::tabItem("indices",
          shiny::fluidRow(
            shinydashboard::box(
              title = "Index Table", width = 12, status = "info",
              shiny::div(style = "overflow-x:auto;",
                         shiny::tableOutput("index_table"))
            )
          )
        ),

        # --- Alerts tab ---
        shinydashboard::tabItem("alerts",
          shiny::fluidRow(
            shinydashboard::box(
              title = "Active Alerts", width = 12, status = "danger",
              shiny::tableOutput("alert_table")
            )
          )
        ),

        # --- Forecast tab ---
        shinydashboard::tabItem("forecast",
          shiny::fluidRow(
            shinydashboard::box(
              title = "3-Month Forecast", width = 12, status = "warning",
              shiny::selectInput("fc_method", "Method",
                                  choices = c("ARIMA" = "arima",
                                              "Moving Average" = "moving_average")),
              shiny::tableOutput("forecast_table")
            )
          )
        ),

        # --- Download tab ---
        shinydashboard::tabItem("download",
          shiny::fluidRow(
            shinydashboard::box(
              title = "Export", width = 6, status = "success",
              shiny::downloadButton("dl_csv",   "Download Index CSV"),
              shiny::br(), shiny::br(),
              shiny::downloadButton("dl_bulletin", "Download HTML Bulletin")
            )
          )
        )
      )
    )
  )

  # ---- Server ----
  server <- function(input, output, session) {

    # Reactive: compute indices
    spi_data <- shiny::reactive({
      shiny::req(input$compute_btn)
      shiny::isolate({
        if (!is.null(input$upload_file)) {
          raw <- import_climate_data(input$upload_file$datapath)
        } else if (!is.null(initial_spi)) {
          return(initial_spi)
        } else {
          shiny::showNotification("Please upload a CSV file or provide data.", type = "warning")
          return(NULL)
        }
        sc <- as.integer(input$scale_choice)
        if (input$index_type == "SPI") calc_spi(raw, scales = sc)
        else                           calc_spei(raw, scales = sc)
      })
    })

    drought_res <- shiny::reactive({
      shiny::req(spi_data())
      detect_drought(spi_data())
    })

    alert_data <- shiny::reactive({
      shiny::req(drought_res())
      generate_alerts(drought_res(), region = input$region_name)
    })

    # Value boxes
    output$vbox_alerts <- shinydashboard::renderValueBox({
      n <- if (!is.null(alert_data())) nrow(alert_data()[alert_data()$alert_level != "NONE", ]) else 0
      shinydashboard::valueBox(n, "Active Alerts", icon = shiny::icon("bell"),
                               color = if (n > 0) "red" else "green")
    })

    output$vbox_episodes <- shinydashboard::renderValueBox({
      n <- if (!is.null(drought_res())) nrow(drought_res()$episodes) else 0
      shinydashboard::valueBox(n, "Drought Episodes", icon = shiny::icon("exclamation-triangle"),
                               color = "orange")
    })

    output$vbox_latest <- shinydashboard::renderValueBox({
      idx_col <- if (!is.null(spi_data())) {
        grep("^(spi|spei)_", names(spi_data()), value = TRUE)[1]
      } else NULL
      val <- if (!is.null(idx_col)) {
        d <- spi_data()[[idx_col]]
        round(d[!is.na(d)][length(d[!is.na(d)])], 2)
      } else "—"
      shinydashboard::valueBox(val, "Latest Index", icon = shiny::icon("tint"),
                               color = "blue")
    })

    output$ts_plot <- plotly::renderPlotly({
      shiny::req(spi_data())
      plot_drought_timeseries(spi_data(), interactive = TRUE)
    })

    output$index_table <- shiny::renderTable({
      shiny::req(spi_data())
      head(spi_data(), 20)
    })

    output$alert_table <- shiny::renderTable({
      shiny::req(alert_data())
      alert_data()[alert_data()$alert_level != "NONE", ]
    })

    output$forecast_table <- shiny::renderTable({
      shiny::req(spi_data())
      forecast_drought(spi_data(), method = input$fc_method, horizon = 3)
    })

    output$dl_csv <- shiny::downloadHandler(
      filename = function() paste0("drought_index_", Sys.Date(), ".csv"),
      content  = function(file) utils::write.csv(spi_data(), file, row.names = FALSE)
    )
  }

  app <- shiny::shinyApp(ui = ui, server = server)
  shiny::runApp(app, launch.browser = launch_browser, port = port)
  invisible(app)
}
