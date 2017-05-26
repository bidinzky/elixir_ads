defmodule Ads.Structure.BinaryToObj do
    alias Ads.Structure.Size
    alias Ads.Structure
    @moduledoc """
        decodes binary data with the given type to an object
    """

    def getDataFromSimpleType(t, d) when t == "BOOL" do
        << x::little-size(8), res::binary>> = d
        result = if x > 0, do: true, else: false
        {result, res}
    end
    def getDataFromSimpleType(t, d) when t == "BYTE" or t == "USINT" or t == "WORD" or t == "UINT" or t == "WORD" or t == "UDINT" or t == "DWORD" do
        size = Size.getSizeOfSimpleType(t)
        << result::little-size(size)-unit(8), res::binary>> = d
        {result, res}
    end
    def getDataFromSimpleType(t, d) when t == "SINT" or t == "INT" or t == "INT16" or t == "DINT" do
        size = Size.getSizeOfSimpleType(t)
        << t::signed-little-size(size)-unit(8), res::binary>> = d
        {t, res}
    end
    def getDataFromSimpleType(t, d) when t == "TIME" or t == "TOD" or t == "TIME_OF_DAY" or t == "DATE" or t == "DT" or t == "DATE_AND_TIME" do
        << data::signed-little-size(4)-unit(8), res::binary>> = d
        data = if t == "DATE" or t == "DT" or t == "DATE_AND_TIME", do: data * 1000, else: data
        {data, res}
    end
    def getDataFromSimpleType(t, d) when t == "REAL" or t == "LREAL" do
        size = Size.getSizeOfSimpleType(t)
        << t::float-little-size(size)-unit(8), res::binary>> = d
        {t, res}
    end
    def getDataFromSimpleType(t, d) do
        size = Size.getSizeOfSimpleType(t)
        << t::binary-size(size)-unit(8), res::binary>> = d
        [t | _] = String.split(t,<<0>>,parts: 2)
        {t, res}
    end

    defp handleList t, d do
        #t = Structure.flatList(t)
        i = t
            |> Enum.find_index(
                fn({k, _}) ->    k == "_len" end
            )
        {{_, len}, b} = List.pop_at(t, i)
        a = if length(b) == 1 do
            {_, b} = Structure.flatList(b)
            Structure.flatList(b)
        else
            b
        end
        {res, d} = Enum.reduce(1..len, {[], d}, fn(_, {l, d}) ->
            {value, d} = serialize(a, d)
            {[value | l], d}
        end)
        {Enum.reverse(res), d}
    end

    def serialize(t, d) when is_list(t) and length(t) > 1 do
        i = Enum.find_index(t, fn({k, _}) ->
            k == "_len"
        end)
        if i == nil do
            {e, d} = Enum.reduce(t, {[], d}, fn({k, v}, {map, data}) ->
                {value, d} = serialize(v, data)
                {[{k,value} | map], d}
            end)
            {Enum.reverse(e), d}
        else
            handleList t, d
        end
    end
    def serialize([a], d) when is_list(a), do: handleList(a, d)
    def serialize([a] = t, d) when not is_list(a), do: serialize(Structure.flatList(t), d)
    def serialize(t, d) when is_bitstring(t) or is_number(t), do: getDataFromSimpleType(t, d)
    def serialize(t, d) do
        {k, v} = t
        {v, r} = serialize(v, d)
        {{k, v}, r}
    end
end
