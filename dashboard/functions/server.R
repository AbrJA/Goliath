plot_lines <- function(p, x, y, i, name, color, size) {
  add_trace(p = p,
            x = x[seq_len(i)],
            y = y[seq_len(i)],
            hovertemplate = paste0("<b>Time</b>: %{x}", "<br><b>Value</b>: %{y:.2f}<extra></extra>"),
            type = "scatter",
            name = name,
            mode = "lines",
            line = list(color = color, width = size[1]))
}

plot_ribbons <- function(p, x, ymin, ymax, color = I("rgba(100, 140, 180, 0.2)"), name = "99% CI") {
  add_ribbons(p = p, x = x, ymin = ymin, ymax = ymax, color = color, name = name,
              line = list(color = "rgba(100, 140, 180, 0.3)", width = 0.5))
}

plot_layout <- function(p, x, i, name, showgrid = TRUE) {
  layout(p,
    xaxis = list(
      title = list(text = paste0("<b>Last</b>: ", round(x[i], 2)), font = list(size = 10, color = "#8899aa")),
      showgrid = showgrid,
      gridcolor = "rgba(255,255,255,0.05)",
      color = "#8899aa",
      zerolinecolor = "rgba(255,255,255,0.05)"
    ),
    yaxis = list(
      title = list(text = name, font = list(size = 10, color = "#8899aa")),
      showgrid = showgrid,
      gridcolor = "rgba(255,255,255,0.05)",
      color = "#8899aa",
      zerolinecolor = "rgba(255,255,255,0.05)"
    ),
    legend = list(orientation = "h", xanchor = "center", x = 0.5, y = -0.15,
                  font = list(color = "#8899aa")),
    paper_bgcolor = "transparent",
    plot_bgcolor = "transparent",
    font = list(color = "#8899aa")
  )
}
