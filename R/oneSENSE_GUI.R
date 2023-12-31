# @Yong Kee

#' A user friendly GUI client for oneSENSE package
#'
#' This GUI provides an easy way for Flow Cytometry data analysis
#' using the oneSENSE package. Main parameters for running 'oneSENSE'
#' were integrated in this GUI, and analysis results are launched
#' in Rstudio after submission.
#'
#'
#' @return GUI for onesense analysis
#' @export
#' @import shiny shinyFiles
#' @importFrom graphics plot
#' @importFrom utils write.csv
#' @examples
#'
#' if (interactive()) oneSENSE::oneSENSE_GUI()
oneSENSE_GUI <- function() {
    ui <- fluidPage(
        titlePanel("OneSENSE"),
        hr(),
        sidebarLayout(
        sidebarPanel(
        shinyDirButton("directory",
            "Folder select",
            "Please select a folder"),
        tags$h4("FCS Folder Selected:"),
        verbatimTextOutput("directorypath"),
        actionButton("firstMarkers",
            "Display Category Markers"),
        actionButton("updatenamescsv",
            "Confirm Marker Selection"),
        numericInput("num", "Ceiling Input", value = 500),
        numericInput("bins", "Bins", value = 250),
        actionButton("submit", "Submit"),
        actionButton("submit2", "Coordinate Selection"),
        br(),
        br(),
        actionButton("submit3", "Generate Frequency heatmap")),
        mainPanel(
            tabsetPanel(id = "Tabset1",
                tabPanel("Marker selection",
                    value = "MkrSelect",
                    flowLayout(checkboxGroupInput("markers1",
                        "Select 1st category markers", ""),
                        checkboxGroupInput("markers2",
                            "Select 2nd category markers", ""),
                        checkboxGroupInput("markers3",
                            "Select 3rd category markers (Optional)", ""))),
                tabPanel("Coordinate Selection",
                    value = "CoordSelect",
                    sidebarLayout(
                    sidebarPanel(
                        uiOutput("markerXdropdown"),
                        uiOutput("markerYdropdown"),
                        tableOutput("table")),
                        mainPanel(plotOutput("plot", click = "plot_click"),
                            actionButton("writecsv", "Generate CSV"))))))))

    server <- function(input, output, session) {

    volumes = getVolumes()
    shinyDirChoose(input, "directory", roots = volumes, session = session)
    output$directorypath <- renderPrint({
        parseDirPath(roots = volumes, input$directory)
    })

    observeEvent(input$firstMarkers, {
        myParam <- getParameters(parseDirPath(volumes, input$directory))
        updateCheckboxGroupInput(session, "markers1", choices = myParam[[1]])
        updateCheckboxGroupInput(session, "markers2", choices = myParam[[1]])
        updateCheckboxGroupInput(session, "markers3", choices = myParam[[1]])
        })
    ## CONFIRM CATEGORY MARKERS TO WRITE CSV ##
    observeEvent(input$updatenamescsv, {
        myParam <- getParameters(parseDirPath(volumes, input$directory))
        paras1 <- c(input$markers1)
        input1 <- rep("", length(myParam[[2]]))
        input1[match(paras1, myParam[[1]])] <- "Y"
        names1 <- data.frame(Marker = myParam[[2]], input = input1)

        paras2 <- c(input$markers2)
        input2 <- rep("", length(myParam[[2]]))
        input2[match(paras2, myParam[[1]])] <- "Y"
        names2 <- data.frame(Marker = myParam[[2]], input = input2)

        paras3 <- c(input$markers3)
        input3 <- rep("", length(myParam[[2]]))
        input3[match(paras3, myParam[[1]])] <- "Y"
        names3 <- data.frame(Marker = myParam[[2]], input = input3)

        if (is.null(input$markers3)) {
            final <- cbind(names1, input2 = names2[, 2])
            write.csv(final,
                paste(dirname(parseDirPath(volumes, input$directory)),
                    "names.csv", sep = .Platform$file.sep), row.names = FALSE)
        } else {
        final <- cbind(names1, input2 = names2[, 2], input3 = names3[, 2])
        write.csv(
            final,
            paste(dirname(parseDirPath(volumes, input$directory)),
                "names.csv", sep = .Platform$file.sep), row.names = FALSE)
        }
    })

    ## DO TSNE AND ONESENSE ##
    observeEvent(input$submit, {
        FCStSNE(LoaderPATH = parseDirPath(volumes, input$directory),
            ceil = input$num, FNnames = "names.csv", OutputSuffix = "Out",
            DotSNE = TRUE, DoOneSENSE = TRUE, Bins = input$bins)
        OneSmapperFlour(
            LoaderPATH = paste(
                            parseDirPath(volumes, input$directory),
                                        "_Out", sep = ""),
                                        Bins = input$bins,
                                        doCoords = FALSE,
                                        doFreq = FALSE)
    })
    observeEvent(input$submit2, {
        myFFdata <- OneSmapperFreq1(
            LoaderPATH = paste(parseDirPath(volumes, input$directory),
                                                    "_Out", sep = ""))
        myCoordslist <- getCoords(
            LoaderPATH = paste(parseDirPath(volumes, input$directory),
                                                    "_Out", sep = ""),
                                                    FFdata = myFFdata)
        updateTabsetPanel(session, "Tabset1", selected = "CoordSelect")
        Mid <- numeric(length = length(myCoordslist$keepnames))
        values <- reactiveValues()
        values$df <- data.frame(Mid, row.names = myCoordslist$keepnames)
        output$markerXdropdown <- renderUI({
        mydata <- myCoordslist$keepnames
        selectInput("markerX", "Marker X", mydata)
        })
        output$markerYdropdown <- renderUI({
        mydata <- myCoordslist$keepnames
        selectInput("markerY", "Marker Y", mydata)
        })
        observe({
        if (!is.null(input$plot_click$x)) {
            isolate(values$df[input$markerX, ] <- input$plot_click$x)
        }
        })
        output$plot <- renderPlot({
        ExpX <- myCoordslist$data1[, input$markerX]
        ExpY <- myCoordslist$data1[, input$markerY]
        plot(ExpX, ExpY, pch = ".",
            xlab = input$markerX,
            ylab = input$markerY,
            cex = 0.1, ylim = c(-1, 4.5),
            xlim = c(-1, 4.5))
        }, width = 400, height = 400)
        output$table <- renderTable(values$df,
                                rownames = TRUE,
                                digits = 10)
        observeEvent(input$writecsv, {
        write.csv(values$df,
                    paste(dirname(parseDirPath(volumes, input$directory)),
                        "Coords.csv",
                        sep = .Platform$file.sep))
        })
    })
    observeEvent(input$submit3, {
        FFdataOSMF2 <- OneSmapperFreq1(
            LoaderPATH = paste(parseDirPath(volumes, input$directory),
                                                    "_Out", sep = ""))
        OneSmapperFreq2(
            LoaderPATH = paste(parseDirPath(volumes, input$directory),
                                                    "_Out", sep = ""),
                        Bins = input$bins, FFdataOSMF2)
    })
    }
    startShinyApp <- shinyApp(ui = ui, server = server)
    runApp(startShinyApp)
}

