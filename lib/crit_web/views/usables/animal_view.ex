defmodule CritWeb.Usables.AnimalView do
  use CritWeb, :view

  def calendar_widget(f, opts) do
    special_defaults = [advice: ""]
    arg = Keyword.merge(special_defaults, opts) |> Enum.into(%{})
    
    field =
      labeled_text_field f, arg.tag, arg.label, %{
        wrapper_extras:
          [data_target: "#{arg.controller}.wrapper"],
        advice: arg.advice,
        input_extras: [
          readonly: true,
          value: arg.default,
          data_target: "#{arg.controller}.input",
          data_action: "click->#{arg.controller}#reveal",
          required: true
        ]
      }
  
    ~E"""
    <div data-controller="<%= arg.controller %>" 
       style="max-width: 540px">

    <%= field %>
    <div id="<%= arg.controller %>" display="none"> </div>
    </div>
    """
  end


  def accumulating_input_widget(f, opts) do
    arg = Enum.into(opts, %{})
    field = labeled_text_field f, arg.tag, arg.label, name: arg.accumulator,
      data_action: "keydown->#{arg.controller}#namecheck",
      data_target: "#{arg.controller}.source"

    

    ~E"""
    <div data-controller="<%=arg.controller%>">
    <%= field %>
    <ul data-target="<%=arg.controller%>.list">
    <ul>
    </div>

    <li><span>Foo</span></li>
    """
  end
    

end
