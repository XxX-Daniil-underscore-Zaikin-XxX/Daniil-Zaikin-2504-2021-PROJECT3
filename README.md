# Daniil-Zaikin-2504-2021-PROJECT3

Good evening. My name is Dan Zaikin, and this is [Project 3](https://courses.smp.uq.edu.au/MATH2504/assessment_html/project3.html).

This code includes both the original and processed data, but should you wish to process your own set, you can do so by running `cleanup.jl`. Note that it includes `info`, `debug`, and `error` messages; you can enable or disable them as per standard Julia fare.

## Task 1

For Task 1, you must first run the following:

```julia
    include("task1.jl")
    df_full = generate_task1_df()
```

If you are using a different file for your data, you can pass its name as a parameter in `generate_task1_df`.

You can then grab each chart of the task as follows:

```julia
    chart1 = plot_rooms(df_full)
    chart2 = plot_price(df_full)
    chart3 = plot_distance(df_full)
    chart4 = plot_method(df_full)
    chart5 = plot_landsize(df_full)
```
