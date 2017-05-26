defmodule Ads.Structure.ObjToBinary do
	alias Ads.Structure.Size
	@moduledoc """
		serializes obj to binary
	"""


	def getBinaryFromSimpleType(type, data), do: getBinaryFromSimpleType(type, data, <<>>)

	def getBinaryFromSimpleType(type, data, chunk) when type == "BOOL" and is_boolean(data), do: chunk <> <<(if data, do: 1, else: 0)::little-size(8)>>

	def getBinaryFromSimpleType(type, data, chunk) when type == "BYTE" or
														type == "USINT" or
														type == "WORD" or
														type == "UINT" or
														type == "WORD" or
														type == "UDINT" or
														type == "DWORD" do
		size = Size.getSizeOfSimpleType(type)
		chunk <> <<data::little-size(size)-unit(8)>>
	end
	def getBinaryFromSimpleType(type, data, chunk) when type == "SINT" or
														type == "INT" or
														type == "INT16" or
														type == "DINT" do
		size = Size.getSizeOfSimpleType(type)
		chunk <> <<data::signed-little-size(size)-unit(8)>>
	end
	def getBinaryFromSimpleType(type, data, chunk) when type == "TIME" or
														type == "TOD" or
														type == "TIME_OF_DAY" or
														type == "DATE" or
														type == "DT" or
														type == "DATE_AND_TIME" do
		data = if type == "DATE" or type == "DT" or type == "DATE_AND_TIME", do: data * 1000, else: data
		chunk <> <<data::little-size(4)-unit(8)>>
	end
	def getBinaryFromSimpleType(type, data, chunk) when type == "REAL" or
														type == "LREAL" do
		size = Size.getSizeOfSimpleType(type)
		chunk <> <<data::float-little-size(size)-unit(8)>>
	end
	def getBinaryFromSimpleType(type, data, chunk) when is_bitstring(type) do
		size = Size.getSizeOfSimpleType(type)
		if byte_size(data) < size do
			d = size - byte_size(data)
			chunk <> data <> Enum.reduce(1..d, <<>>, fn(_, acc) -> acc <> <<0>> end)
		else
			chunk <> <<data::binary-size(size)>>
		end
	end

	def deserialize(type, data) do
		deserialize(type,data,<<>>)
	end
	def deserialize(type,data, chunk) when is_bitstring(type) do
		chunk <> getBinaryFromSimpleType(type,data)
	end
	def deserialize(type, data, chunk) when is_list(type) and length(type) > 1 do
		i = Enum.find_index(type,fn({k,_}) -> 
			k == "_len"
		end)
		if i == nil do
			Enum.reduce(type,{chunk, data}, fn({k,v}, {chunk,data}) ->
				[{^k, d} | d2] = data

				{deserialize(v,d,chunk), d2}
			end)
		else
			{{_,_},b} = List.pop_at(type,i)
			b = Ads.Structure.flatList(b)
			Enum.reduce(data, chunk, fn(d,chunk) ->
				deserialize(b,d,chunk)
			end)          	
		end
	end
	def deserialize([t] = type,[d],chunk) when is_list(type) do
		deserialize(t,d,chunk)
	end
	def deserialize(type,data,chunk) when is_tuple(data) do
		{k,v} = type
		{^k, value} = data
		deserialize(v,value,chunk)
	end
	def deserialize({_,v},data, chunk) do
		deserialize(v,data,chunk)
	end
end
