defmodule Ads.Structure.Size do
    alias Ads.Structure
    @moduledoc"""
        computes the size of an type
    """

    def getSizeOfSimpleType(t) when t == "BOOL" or t == "BYTE" or t == "USINT" or t == "SINT", do: 1
    def getSizeOfSimpleType(t) when t == "WORD" or t == "UINT" or t == "INT" or t == "INT16", do: 2
    def getSizeOfSimpleType(t) when t == "LREAL", do: 8
    def getSizeOfSimpleType(<<83, 84, 82, 73, 78, 71>>), do: 256
    def getSizeOfSimpleType(<<83, 84, 82, 73, 78, 71, 46, data::binary>>) do
        {n, ""} = Integer.parse(data)
        n + 1
    end
    def getSizeOfSimpleType(t) when is_number(t), do: t
    def getSizeOfSimpleType(_), do: 4

    defp handleList t do
        t = Structure.flatList(t)
        i = t
            |> Enum.find_index(fn({k, _}) ->
                k == "_len"
            end)
        {{_, len}, b} = List.pop_at(t, i)
        len * size(b)
    end
    defp handlePropList t do
        i = Enum.find_index(t, fn({k, _}) ->
            k == "_len"
        end)
        if i == nil do
            Enum.reduce(t, 0, fn({_, v}, acc) ->
                size(v) + acc
            end)
        else
            handleList t
        end
    end

    def size(t) when is_list(t) and length(t) > 1 do
    	handlePropList(t)
    end

    def size(t) when is_list(t) do
    	[a] = t
    	if is_list(a) do
            handleList(t)
    	else
    		handlePropList(t)
    	end
    end
    def size(t) when is_bitstring(t) or is_number(t), do: getSizeOfSimpleType(t)
    def size({_,v}) do
    	size v
    end
end
