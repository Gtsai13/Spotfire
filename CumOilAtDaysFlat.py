from Spotfire.Dxp.Data import AddRowsSettings
from System.IO import StringReader, StreamReader, StreamWriter, MemoryStream, SeekOrigin
from Spotfire.Dxp.Data.Import import TextFileDataSource, TextDataReaderSettings
from Spotfire.Dxp.Data import *


dataTable = Document.Data.Tables["Oxy Eag Daily Production"]
rowIndexSet=Document.ActiveMarkingSelectionReference.GetSelection(dataTable).AsIndexSet()
cursor = DataValueCursor.CreateFormatted(dataTable.Columns["Cum Oil at Days Flat"])
list = []




"""c.Index or the .Index function in this case actually returns the row indexes for all marked rowIndexSet
for c in dataTable.GetRows(rowIndexSet, cursor):
	print c.Index
For example the output is below:
23207
23208
23209
23210
23211
23212
"""		



""" Trying to figure out what .CurrentValue does
for c in dataTable.GetRows(rowIndexSet, cursor):
	rowIndex = c.Index
	print cursor.CurrentValue
it actually returns a column of the current value for all of the row indexes for the markes rowIndexSet
Example output:
0.00
(Empty)
(Empty)
(Empty)
(Empty)
(Empty)
"""


for c in dataTable.GetRows(rowIndexSet, cursor):
	rowIndex = c.Index
	if (str(cursor.CurrentValue) != str("(Empty)")):
		list.append(cursor.CurrentValue)
		x = max(list)
		x = float(x)/1000
		print x

Document.Properties["CumOilatDaysFlat"] = x
