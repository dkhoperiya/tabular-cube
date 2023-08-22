using System.IO;

var dax = @"EVALUATE " +
"UNION (" +
"    ROW(\"Table\",\"ProjectExpenses_RMS\", \"RowCount\", COUNTROWS( ProjectExpenses_RMS ))," +
"    ROW(\"Table\",\"Assignments History\", \"RowCount\", COUNTROWS( 'Assignments History'))" +
")";

var file = @"artifacts\CountRow.csv";
var columnSeparator = ";";

using(var daxReader = ExecuteReader(dax)){
   using(var fileWriter = new StreamWriter(file))
   {
       // Write column headers:
       fileWriter.WriteLine(string.Join(columnSeparator, Enumerable.Range(0, daxReader.FieldCount - 1).Select(f => daxReader.GetName(f))));

       while(daxReader.Read())
       {
           var rowValues = new object[daxReader.FieldCount];
           daxReader.GetValues(rowValues);
           var row = string.Join(columnSeparator, rowValues.Select(v => v == null ? "" : v.ToString()));
           fileWriter.WriteLine(row);
       }
   }
}