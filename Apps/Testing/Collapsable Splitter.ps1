@'
<head>
    <title></title>
    <!-- Ignite UI Required Combined CSS Files -->
    <link href="http://cdn-na.infragistics.com/igniteui/2016.1/latest/css/themes/infragistics/infragistics.theme.css" rel="stylesheet" />
    <link href="http://cdn-na.infragistics.com/igniteui/2016.1/latest/css/structure/infragistics.css" rel="stylesheet" />

    <!-- Modernizr/jQuery/jQuery UI -->
    <script src="http://ajax.aspnetcdn.com/ajax/modernizr/modernizr-2.8.3.js"></script>
    <script src="http://code.jquery.com/jquery-1.9.1.min.js"></script>
    <script src="http://code.jquery.com/ui/1.10.3/jquery-ui.min.js"></script>
    <script src="http://www.igniteui.com/data-files/js-controls.js"></script>

    <!-- Ignite UI Required Combined JavaScript Files -->
    
    <script src="http://cdn-na.infragistics.com/igniteui/2016.1/latest/js/infragistics.core.js"></script>
    <script src="http://cdn-na.infragistics.com/igniteui/2016.1/latest/js/infragistics.lob.js"></script>
</head>
<body>
    <style type="text/css">
        #dashboard {
            border: 1px solid #bcbcbc;
        }

        #dashboard .ig-layout-item {
            z-index: 2;
        }

        .minimized-state-header {
            font-size: 16px;
            margin-bottom: 6px;
        }

        .minimized-state-body {
            font-size: 14px;
        }

        .maximized-state-header {
            font-size: 18px;
            margin-bottom: 8px;
        }

        .maximized-state-body {
            font-size: 16px;
        }

        .ui-igtilemanager.ui-igsplitter .ui-igsplitter-splitbar-vertical,
        .ui-igsplitter-splitbar-vertical {
            width: 6px;
        }

        .ui-igtilemanager.ui-igsplitter .ui-igsplitter-collapse-single-button,
        .ui-igsplitter-collapse-single-button {
            z-index: 1;
            width: 25px;
            height: 25px;
            border: 1px solid #bcbcbc;
            border-radius: 20px;
            margin-left: -11px;
        }

        .ui-igsplitter-collapse-single-button .ui-icon-triangle-1-w {
            background: url(http://www.igniteui.com/images/samples/tile-manager/collapsible-splitter/left-arrow-gray.svg) 0px 0px/16px 16px !important;
        }

        .ui-igsplitter-collapse-single-button.ui-state-hover .ui-icon-triangle-1-w {
            background-image: url(http://www.igniteui.com/images/samples/tile-manager/collapsible-splitter/left-arrow-white.svg) !important;
        }

        .ui-igsplitter-collapse-single-button .ui-icon-triangle-1-e {
            background: url(http://www.igniteui.com/images/samples/tile-manager/collapsible-splitter/right-arrow-gray.svg) 0px 0px/16px 16px !important;
        }

        .ui-igsplitter-collapse-single-button.ui-state-hover .ui-icon-triangle-1-e {
            background-image: url(http://www.igniteui.com/images/samples/tile-manager/collapsible-splitter/right-arrow-white.svg) !important;
        }

        .ui-igsplitter-collapse-single-button .ui-icon:before,
        .ui-igsplitter-collapse-single-button.ui-state-hover .ui-icon:before {
            content: '';
        }

        body .ui-igsplitter-splitbar-vertical:last-child .ui-igsplitter-collapse-single-button {
            display: none;
        }
    </style>
    <div id="dashboard">
    </div>
    <script type="text/javascript">
        $(function () {
            $('#dashboard').igTileManager({
                width: "100%",
                height: "500px",
                columnWidth: 200,
                columnHeight: 200,
                marginLeft: 20,
                marginTop: 20,
                animationDuration: 300,
                dataSource: controls,
                splitterOptions: {
                    enabled: true,
                    collapsed: false,
                    collapsible: true
                },
                rendered: function (evt, ui) {
                    ui.owner.maximize(ui.owner.minimizedTiles().first());
                },
                minimizedState: "<h3 class='minimized-state-header'>${name}</h3><p class='minimized-state-body'>${description}</p>",
                maximizedState: "<h3 class='maximized-state-header'>${name}</h3><p class='maximized-state-body'>${description}</p>"
            });
        });
    </script>
'@